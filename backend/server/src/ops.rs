use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use crate::{
    auth::CurrentUser,
    error::{AppError, AppResult},
    state::AppState,
};

fn rows(inner: &str) -> String {
    format!("SELECT coalesce(json_agg(row_to_json(q)), '[]'::json) FROM ({inner}) q")
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/applications", get(list_applications))
        .route("/applications/{id}/provision", post(provision))
}

async fn list_applications(user: CurrentUser, State(st): State<AppState>) -> AppResult<Json<Value>> {
    user.require("queue:read")?;
    let (v,): (Value,) = sqlx::query_as(&rows(
        "SELECT iq.id, iq.queue_type::text, iq.status::text, iq.requested_at, \
                iq.applicant_last_name, iq.applicant_first_name, \
                a.postal_index, a.district, a.street, a.house, a.apartment, \
                iq.desired_pbx_id, p.name AS desired_pbx_name, \
                iq.customer_id, c.login AS customer_login, \
                (SELECT count(*) FROM phone_number pn \
                   WHERE pn.pbx_id = iq.desired_pbx_id AND pn.status = 'free') AS free_on_desired \
         FROM installation_queue iq \
         JOIN address a ON a.id = iq.address_id \
         LEFT JOIN pbx p ON p.id = iq.desired_pbx_id \
         LEFT JOIN customer c ON c.id = iq.customer_id \
         ORDER BY (iq.status = 'installed'), iq.requested_at",
    ))
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

#[derive(Deserialize)]
struct ProvisionInput {
    pbx_id: Option<i64>,
    line_type: Option<String>,
}

async fn provision(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
    Json(input): Json<ProvisionInput>,
) -> AppResult<Json<Value>> {
    user.require("queue:update")?;
    let pool = st.pool();

    let app: Option<(String, i64, Option<i64>, Option<i64>)> = sqlx::query_as(
        "SELECT status::text, address_id, desired_pbx_id, customer_id \
         FROM installation_queue WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?;
    let Some((status, address_id, desired_pbx_id, customer_id)) = app else {
        return Err(AppError::NotFound);
    };
    if status == "installed" {
        return Err(AppError::bad_request("заявка уже выполнена"));
    }
    let customer_id =
        customer_id.ok_or_else(|| AppError::bad_request("заявка без аккаунта абонента"))?;
    let pbx_id = input
        .pbx_id
        .or(desired_pbx_id)
        .ok_or_else(|| AppError::bad_request("укажите АТС для подключения"))?;
    let line_type = input.line_type.unwrap_or_else(|| "main".into());

    let free: Option<(i64,)> = sqlx::query_as(
        "SELECT id FROM phone_number WHERE pbx_id = $1 AND status = 'free' ORDER BY number LIMIT 1",
    )
    .bind(pbx_id)
    .fetch_optional(pool)
    .await?;
    let number_id = free
        .ok_or_else(|| AppError::bad_request("на выбранной АТС нет свободных номеров"))?
        .0;

    let (pbx_type,): (String,) = sqlx::query_as("SELECT pbx_type::text FROM pbx WHERE id = $1")
        .bind(pbx_id)
        .fetch_one(pool)
        .await?;
    let intercity = if pbx_type == "city" { "closed" } else { "none" };

    let mut tx = pool.begin().await?;
    sqlx::query(
        "UPDATE phone_number SET line_type = $2::line_type, intercity = $3::intercity_status, \
                address_id = $4 WHERE id = $1",
    )
    .bind(number_id)
    .bind(&line_type)
    .bind(intercity)
    .bind(address_id)
    .execute(&mut *tx)
    .await?;

    let (subscriber_id,): (i64,) = sqlx::query_as(
        "INSERT INTO subscriber \
            (last_name, first_name, middle_name, gender, birth_date, category, privilege, \
             phone_number_id, address_id, customer_id, connected_at) \
         SELECT c.last_name, c.first_name, c.middle_name, c.gender, c.birth_date, \
                c.category, c.privilege, $1, $2, c.id, CURRENT_DATE \
         FROM customer c WHERE c.id = $3 RETURNING id",
    )
    .bind(number_id)
    .bind(address_id)
    .bind(customer_id)
    .fetch_one(&mut *tx)
    .await?;

    sqlx::query(
        "INSERT INTO invoice (subscriber_id, kind, period_year, period_month, amount, due_date, status) \
         SELECT $1, 'subscription', \
                extract(year FROM CURRENT_DATE)::smallint, extract(month FROM CURRENT_DATE)::smallint, \
                fn_subscriber_monthly_fee($1), \
                make_date(extract(year FROM CURRENT_DATE)::int, extract(month FROM CURRENT_DATE)::int, 20), 'pending' \
         ON CONFLICT (subscriber_id, kind, period_year, period_month) DO NOTHING",
    )
    .bind(subscriber_id)
    .execute(&mut *tx)
    .await?;

    sqlx::query("UPDATE installation_queue SET status = 'installed', assigned_number_id = $2 WHERE id = $1")
        .bind(id)
        .bind(number_id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;

    let (number,): (String,) = sqlx::query_as("SELECT number FROM phone_number WHERE id = $1")
        .bind(number_id)
        .fetch_one(pool)
        .await?;

    Ok(Json(json!({
        "subscriber_id": subscriber_id,
        "number_id": number_id,
        "number": number,
    })))
}
