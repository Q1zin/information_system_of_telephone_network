use axum::{
    extract::{FromRef, FromRequestParts, Path, State},
    http::request::Parts,
    routing::{get, post, put},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use tower_sessions::Session;

use crate::{
    auth::password::{hash_password, verify_password},
    error::{AppError, AppResult},
    state::AppState,
};

const CUSTOMER_ID_KEY: &str = "customer_id";

fn rows(inner: &str) -> String {
    format!("SELECT coalesce(json_agg(row_to_json(q)), '[]'::json) FROM ({inner}) q")
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/register", post(register))
        .route("/login", post(login))
        .route("/logout", post(logout))
        .route("/me", get(me))
        .route("/overview", get(overview))
        .route("/applications", get(list_applications).post(apply))
        .route("/pbx-options", get(pbx_options))
        .route("/cities", get(cities))
        .route("/tariffs", get(tariffs))
        .route("/lines/{number_id}/intercity", put(set_intercity))
        .route("/lines/{number_id}/call", post(make_call))
        .route("/lines/{number_id}/calls", get(call_history))
        .route("/invoices", get(invoices))
        .route("/invoices/{id}/pay", post(pay_invoice))
}

#[derive(Clone, Debug, Serialize)]
pub struct CurrentCustomer {
    pub id: i64,
    pub login: String,
    pub last_name: String,
    pub first_name: String,
    pub middle_name: Option<String>,
    pub category: String,
}

async fn load_customer(pool: &sqlx::PgPool, id: i64) -> AppResult<Option<CurrentCustomer>> {
    let row = sqlx::query_as::<_, (i64, String, String, String, Option<String>, String)>(
        "SELECT id, login, last_name, first_name, middle_name, category::text \
         FROM customer WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(|(id, login, last_name, first_name, middle_name, category)| CurrentCustomer {
        id,
        login,
        last_name,
        first_name,
        middle_name,
        category,
    }))
}

impl<S> FromRequestParts<S> for CurrentCustomer
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let session = Session::from_request_parts(parts, state)
            .await
            .map_err(|_| AppError::Unauthorized)?;
        let id: Option<i64> = session
            .get(CUSTOMER_ID_KEY)
            .await
            .map_err(|_| AppError::Unauthorized)?;
        let id = id.ok_or(AppError::Unauthorized)?;
        let app = AppState::from_ref(state);
        load_customer(app.pool(), id).await?.ok_or(AppError::Unauthorized)
    }
}

#[derive(Deserialize)]
struct RegisterInput {
    login: String,
    password: String,
    last_name: String,
    first_name: String,
    middle_name: Option<String>,
    gender: String,
    birth_date: String,
    category: Option<String>,
    privilege: Option<String>,
}

async fn register(
    State(st): State<AppState>,
    session: Session,
    Json(input): Json<RegisterInput>,
) -> AppResult<Json<CurrentCustomer>> {
    if input.password.len() < 4 {
        return Err(AppError::bad_request("пароль должен быть не короче 4 символов"));
    }
    let hash = hash_password(&input.password)?;
    let category = input.category.unwrap_or_else(|| "regular".into());
    let (id,): (i64,) = sqlx::query_as(
        "INSERT INTO customer \
            (login, password_hash, last_name, first_name, middle_name, gender, birth_date, category, privilege) \
         VALUES ($1, $2, $3, $4, $5, $6::gender, $7::date, $8::subscriber_category, $9::privilege_kind) \
         RETURNING id",
    )
    .bind(&input.login)
    .bind(&hash)
    .bind(&input.last_name)
    .bind(&input.first_name)
    .bind(&input.middle_name)
    .bind(&input.gender)
    .bind(&input.birth_date)
    .bind(&category)
    .bind(&input.privilege)
    .fetch_one(st.pool())
    .await?;

    session
        .insert(CUSTOMER_ID_KEY, id)
        .await
        .map_err(|e| AppError::Other(anyhow::anyhow!("session error: {e}")))?;
    Ok(Json(load_customer(st.pool(), id).await?.unwrap()))
}

#[derive(Deserialize)]
struct LoginInput {
    login: String,
    password: String,
}

async fn login(
    State(st): State<AppState>,
    session: Session,
    Json(input): Json<LoginInput>,
) -> AppResult<Json<CurrentCustomer>> {
    let row = sqlx::query_as::<_, (i64, String)>(
        "SELECT id, password_hash FROM customer WHERE login = $1",
    )
    .bind(&input.login)
    .fetch_optional(st.pool())
    .await?;
    let Some((id, hash)) = row else {
        return Err(AppError::Unauthorized);
    };
    if !verify_password(&input.password, &hash) {
        return Err(AppError::Unauthorized);
    }
    session
        .insert(CUSTOMER_ID_KEY, id)
        .await
        .map_err(|e| AppError::Other(anyhow::anyhow!("session error: {e}")))?;
    Ok(Json(load_customer(st.pool(), id).await?.unwrap()))
}

async fn logout(session: Session) -> AppResult<Json<Value>> {
    session
        .flush()
        .await
        .map_err(|e| AppError::Other(anyhow::anyhow!("session error: {e}")))?;
    Ok(Json(json!({ "status": "ok" })))
}

async fn me(customer: CurrentCustomer) -> Json<CurrentCustomer> {
    Json(customer)
}

async fn overview(customer: CurrentCustomer, State(st): State<AppState>) -> AppResult<Json<Value>> {
    let pool = st.pool();
    let (lines,): (Value,) = sqlx::query_as(&rows(
        "SELECT s.id AS subscriber_id, pn.id AS number_id, pn.number, \
                pn.line_type::text, pn.intercity::text, pn.status::text, \
                p.id AS pbx_id, p.name AS pbx_name, p.pbx_type::text, \
                fn_subscriber_monthly_fee(s.id) AS monthly_fee \
         FROM subscriber s \
         JOIN phone_number pn ON pn.id = s.phone_number_id \
         JOIN pbx p ON p.id = pn.pbx_id \
         WHERE s.customer_id = $1 ORDER BY pn.number",
    ))
    .bind(customer.id)
    .fetch_one(pool)
    .await?;

    let (debt,): (rust_decimal::Decimal,) = sqlx::query_as(
        "SELECT coalesce(sum(d.total_debt), 0) FROM v_subscriber_debt d \
         JOIN subscriber s ON s.id = d.subscriber_id WHERE s.customer_id = $1",
    )
    .bind(customer.id)
    .fetch_one(pool)
    .await?;

    let (apps,): (Value,) = sqlx::query_as(&rows(
        "SELECT iq.id, iq.queue_type::text, iq.status::text, iq.requested_at, \
                a.district, a.street, a.house, a.apartment, p.name AS desired_pbx_name \
         FROM installation_queue iq \
         JOIN address a ON a.id = iq.address_id \
         LEFT JOIN pbx p ON p.id = iq.desired_pbx_id \
         WHERE iq.customer_id = $1 ORDER BY iq.requested_at DESC",
    ))
    .bind(customer.id)
    .fetch_one(pool)
    .await?;

    Ok(Json(json!({
        "customer": customer,
        "lines": lines,
        "total_debt": debt,
        "applications": apps,
    })))
}

#[derive(Deserialize)]
struct ApplyInput {
    postal_index: String,
    district: String,
    street: String,
    house: String,
    apartment: Option<String>,
    desired_pbx_id: Option<i64>,
}

async fn apply(
    customer: CurrentCustomer,
    State(st): State<AppState>,
    Json(input): Json<ApplyInput>,
) -> AppResult<Json<Value>> {
    let pool = st.pool();
    let (address_id,): (i64,) = sqlx::query_as(
        "INSERT INTO address (postal_index, district, street, house, apartment) \
         VALUES ($1, $2, $3, $4, $5) RETURNING id",
    )
    .bind(&input.postal_index)
    .bind(&input.district)
    .bind(&input.street)
    .bind(&input.house)
    .bind(&input.apartment)
    .fetch_one(pool)
    .await?;

    let queue_type = if customer.category == "privileged" {
        "privileged"
    } else {
        "regular"
    };

    let (id,): (i64,) = sqlx::query_as(
        "INSERT INTO installation_queue \
            (applicant_last_name, applicant_first_name, applicant_middle_name, \
             queue_type, address_id, desired_pbx_id, customer_id) \
         VALUES ($1, $2, $3, $4::queue_type, $5, $6, $7) RETURNING id",
    )
    .bind(&customer.last_name)
    .bind(&customer.first_name)
    .bind(&customer.middle_name)
    .bind(queue_type)
    .bind(address_id)
    .bind(input.desired_pbx_id)
    .bind(customer.id)
    .fetch_one(pool)
    .await?;

    Ok(Json(json!({ "id": id, "status": "waiting" })))
}

async fn list_applications(
    customer: CurrentCustomer,
    State(st): State<AppState>,
) -> AppResult<Json<Value>> {
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT iq.id, iq.queue_type::text, iq.status::text, iq.requested_at, \
                a.district, a.street, a.house, a.apartment, p.name AS desired_pbx_name \
         FROM installation_queue iq \
         JOIN address a ON a.id = iq.address_id \
         LEFT JOIN pbx p ON p.id = iq.desired_pbx_id \
         WHERE iq.customer_id = $1 ORDER BY iq.requested_at DESC",
    ))
    .bind(customer.id)
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

async fn pbx_options(_c: CurrentCustomer, State(st): State<AppState>) -> AppResult<Json<Value>> {
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT pbx_id AS id, name, pbx_type::text, district, free_numbers \
         FROM v_pbx_stats ORDER BY name",
    ))
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

async fn cities(_c: CurrentCustomer, State(st): State<AppState>) -> AppResult<Json<Value>> {
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT id, name, is_home FROM city ORDER BY is_home DESC, name",
    ))
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

async fn tariffs(_c: CurrentCustomer, State(st): State<AppState>) -> AppResult<Json<Value>> {
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT line_type::text, with_intercity, monthly_fee FROM tariff ORDER BY line_type, with_intercity",
    ))
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

async fn owned_subscriber(pool: &sqlx::PgPool, customer_id: i64, number_id: i64) -> AppResult<i64> {
    let row: Option<(i64,)> = sqlx::query_as(
        "SELECT s.id FROM subscriber s WHERE s.customer_id = $1 AND s.phone_number_id = $2",
    )
    .bind(customer_id)
    .bind(number_id)
    .fetch_optional(pool)
    .await?;
    row.map(|(id,)| id).ok_or(AppError::Forbidden)
}

#[derive(Deserialize)]
struct IntercityInput {
    enabled: bool,
}

async fn set_intercity(
    customer: CurrentCustomer,
    State(st): State<AppState>,
    Path(number_id): Path<i64>,
    Json(input): Json<IntercityInput>,
) -> AppResult<Json<Value>> {
    let pool = st.pool();
    owned_subscriber(pool, customer.id, number_id).await?;

    let current: (String,) =
        sqlx::query_as("SELECT intercity::text FROM phone_number WHERE id = $1")
            .bind(number_id)
            .fetch_one(pool)
            .await?;
    if current.0 == "none" {
        return Err(AppError::bad_request(
            "межгород недоступен на этой АТС (замкнутая сеть)",
        ));
    }
    let new = if input.enabled { "open" } else { "closed" };
    sqlx::query("UPDATE phone_number SET intercity = $2::intercity_status WHERE id = $1")
        .bind(number_id)
        .bind(new)
        .execute(pool)
        .await?;
    Ok(Json(json!({ "number_id": number_id, "intercity": new })))
}

#[derive(Deserialize)]
struct CallInput {
    kind: String, // 'local' | 'intercity'
    dest_number: Option<String>,
    dest_city_id: Option<i64>,
    duration_sec: Option<i32>,
}

async fn make_call(
    customer: CurrentCustomer,
    State(st): State<AppState>,
    Path(number_id): Path<i64>,
    Json(input): Json<CallInput>,
) -> AppResult<Json<Value>> {
    let pool = st.pool();
    let subscriber_id = owned_subscriber(pool, customer.id, number_id).await?;
    let duration = input.duration_sec.unwrap_or(60).clamp(1, 36_000);

    if input.kind == "intercity" {
        let intercity: (String,) =
            sqlx::query_as("SELECT intercity::text FROM phone_number WHERE id = $1")
                .bind(number_id)
                .fetch_one(pool)
                .await?;
        if intercity.0 != "open" {
            return Err(AppError::bad_request(
                "межгород закрыт — включите услугу в настройках линии",
            ));
        }
        let city_id = input
            .dest_city_id
            .ok_or_else(|| AppError::bad_request("укажите город назначения"))?;
        let minutes = (duration as f64 / 60.0).ceil();
        let cost = rust_decimal::Decimal::try_from(minutes * 5.0).unwrap_or_default();

        let (call_id,): (i64,) = sqlx::query_as(
            "INSERT INTO call_record (from_number_id, call_type, dest_city_id, started_at, duration_sec, cost) \
             VALUES ($1, 'intercity', $2, now(), $3, $4) RETURNING id",
        )
        .bind(number_id)
        .bind(city_id)
        .bind(duration)
        .bind(cost)
        .fetch_one(pool)
        .await?;

        sqlx::query(
            "INSERT INTO invoice (subscriber_id, kind, period_year, period_month, amount, due_date, status) \
             SELECT $1, 'intercity', \
                    extract(year FROM CURRENT_DATE)::smallint, extract(month FROM CURRENT_DATE)::smallint, \
                    $2, make_date(extract(year FROM CURRENT_DATE)::int, extract(month FROM CURRENT_DATE)::int, 20), 'pending' \
             ON CONFLICT (subscriber_id, kind, period_year, period_month) \
             DO UPDATE SET amount = invoice.amount + EXCLUDED.amount, status = 'pending'",
        )
        .bind(subscriber_id)
        .bind(cost)
        .execute(pool)
        .await?;

        return Ok(Json(json!({ "call_id": call_id, "type": "intercity", "cost": cost })));
    }

    let dest = input
        .dest_number
        .ok_or_else(|| AppError::bad_request("укажите номер вызываемого абонента"))?;
    let dest_id: Option<(i64,)> = sqlx::query_as("SELECT id FROM phone_number WHERE number = $1")
        .bind(&dest)
        .fetch_optional(pool)
        .await?;
    let dest_id = dest_id.ok_or_else(|| AppError::bad_request("номер не найден в сети"))?.0;

    let (call_id,): (i64,) = sqlx::query_as(
        "INSERT INTO call_record (from_number_id, call_type, dest_number_id, started_at, duration_sec, cost) \
         VALUES ($1, 'local', $2, now(), $3, 0) RETURNING id",
    )
    .bind(number_id)
    .bind(dest_id)
    .bind(duration)
    .fetch_one(pool)
    .await?;
    Ok(Json(json!({ "call_id": call_id, "type": "local", "cost": 0 })))
}

async fn call_history(
    customer: CurrentCustomer,
    State(st): State<AppState>,
    Path(number_id): Path<i64>,
) -> AppResult<Json<Value>> {
    let pool = st.pool();
    owned_subscriber(pool, customer.id, number_id).await?;
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT cr.id, cr.call_type::text, cr.started_at, cr.duration_sec, cr.cost, \
                c.name AS dest_city, dn.number AS dest_number \
         FROM call_record cr \
         LEFT JOIN city c ON c.id = cr.dest_city_id \
         LEFT JOIN phone_number dn ON dn.id = cr.dest_number_id \
         WHERE cr.from_number_id = $1 ORDER BY cr.started_at DESC LIMIT 50",
    ))
    .bind(number_id)
    .fetch_one(pool)
    .await?;
    Ok(Json(v))
}

async fn invoices(customer: CurrentCustomer, State(st): State<AppState>) -> AppResult<Json<Value>> {
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT i.id, i.kind::text, i.period_year, i.period_month, i.amount, \
                i.due_date, i.status::text, pn.number \
         FROM invoice i \
         JOIN subscriber s ON s.id = i.subscriber_id \
         JOIN phone_number pn ON pn.id = s.phone_number_id \
         WHERE s.customer_id = $1 ORDER BY i.due_date DESC, i.id DESC",
    ))
    .bind(customer.id)
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

async fn pay_invoice(
    customer: CurrentCustomer,
    State(st): State<AppState>,
    Path(id): Path<i64>,
) -> AppResult<Json<Value>> {
    let pool = st.pool();
    let row: Option<(i64, rust_decimal::Decimal, String, String)> = sqlx::query_as(
        "SELECT i.subscriber_id, i.amount, i.status::text, i.kind::text \
         FROM invoice i JOIN subscriber s ON s.id = i.subscriber_id \
         WHERE i.id = $1 AND s.customer_id = $2",
    )
    .bind(id)
    .bind(customer.id)
    .fetch_optional(pool)
    .await?;
    let Some((subscriber_id, amount, status, kind)) = row else {
        return Err(AppError::NotFound);
    };
    if status == "paid" {
        return Err(AppError::bad_request("счёт уже оплачен"));
    }

    let mut tx = pool.begin().await?;
    sqlx::query("INSERT INTO payment (subscriber_id, invoice_id, amount) VALUES ($1, $2, $3)")
        .bind(subscriber_id)
        .bind(id)
        .bind(amount)
        .execute(&mut *tx)
        .await?;
    sqlx::query("UPDATE invoice SET status = 'paid' WHERE id = $1")
        .bind(id)
        .execute(&mut *tx)
        .await?;

    let notice_kind = if kind == "intercity" {
        "intercity_debt"
    } else {
        "subscription_debt"
    };
    sqlx::query(
        "UPDATE notification SET resolved = TRUE \
         WHERE subscriber_id = $1 AND kind = $2::notification_kind AND NOT resolved",
    )
    .bind(subscriber_id)
    .bind(notice_kind)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;

    Ok(Json(json!({ "paid": id, "amount": amount })))
}
