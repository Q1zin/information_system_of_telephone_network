//! Variant analytical queries (req. 2). Each endpoint builds parameterised SQL
//! and lets PostgreSQL render the result set as JSON via `json_agg`.

use axum::{
    extract::{Query, State},
    routing::get,
    Json, Router,
};
use serde::Deserialize;
use serde_json::Value;

use crate::{auth::CurrentUser, error::AppResult, state::AppState};

const PERM: &str = "analytics:read";

fn wrap(inner: &str) -> String {
    format!("SELECT coalesce(json_agg(row_to_json(q)), '[]'::json) FROM ({inner}) q")
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/subscribers", get(q1_subscribers))
        .route("/free-numbers", get(q2_free_numbers))
        .route("/debtors", get(q3_debtors))
        .route("/pbx-debt-ranking", get(q4_pbx_ranking))
        .route("/public-phones", get(q5_public_phones))
        .route("/category-ratio", get(q6_category_ratio))
        .route("/parallel-subscribers", get(q7_parallel))
        .route("/phones-by-address", get(q8_phones_by_address))
        .route("/top-intercity-city", get(q9_top_city))
        .route("/subscriber-by-number", get(q10_by_number))
        .route("/splittable-paired", get(q11_splittable))
        .route("/low-external-call-numbers", get(q12_low_external))
        .route("/action-needed-debtors", get(q13_action_needed))
}

/// Q1. Subscribers of a PBX (all / privileged / by age / by surname prefix).
#[derive(Deserialize)]
struct Q1 {
    pbx_id: Option<i64>,
    category: Option<String>,
    min_age: Option<i32>,
    max_age: Option<i32>,
    surname: Option<String>,
}

async fn q1_subscribers(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q1>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT * FROM v_subscriber_full \
         WHERE ($1::bigint IS NULL OR pbx_id = $1) \
           AND ($2::text   IS NULL OR category::text = $2) \
           AND ($3::int    IS NULL OR age >= $3) \
           AND ($4::int    IS NULL OR age <= $4) \
           AND ($5::text   IS NULL OR last_name ILIKE $5 || '%') \
         ORDER BY last_name, first_name",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.category)
        .bind(p.min_age)
        .bind(p.max_age)
        .bind(p.surname)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q2. Free numbers (by PBX / whole network / by district).
#[derive(Deserialize)]
struct Q2 {
    pbx_id: Option<i64>,
    district: Option<String>,
}

async fn q2_free_numbers(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q2>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT pn.id, pn.number, pn.line_type, pn.intercity, \
                p.name AS pbx_name, p.district \
         FROM phone_number pn JOIN pbx p ON p.id = pn.pbx_id \
         WHERE pn.status = 'free' \
           AND ($1::bigint IS NULL OR pn.pbx_id = $1) \
           AND ($2::text   IS NULL OR p.district = $2) \
         ORDER BY pn.number",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.district)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q3. Debtors (by PBX / district / overdue days / debt kind / amount).
#[derive(Deserialize)]
struct Q3 {
    pbx_id: Option<i64>,
    district: Option<String>,
    min_days: Option<i32>,
    kind: Option<String>,
    min_amount: Option<f64>,
}

async fn q3_debtors(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q3>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT vf.id, vf.last_name, vf.first_name, vf.number, \
                vf.pbx_name, vf.pbx_district, \
                d.subscription_debt, d.intercity_debt, d.penalty_debt, d.total_debt, \
                (CURRENT_DATE - d.oldest_due_date) AS days_overdue \
         FROM v_subscriber_debt d JOIN v_subscriber_full vf ON vf.id = d.subscriber_id \
         WHERE d.total_debt > 0 \
           AND ($1::bigint  IS NULL OR vf.pbx_id = $1) \
           AND ($2::text    IS NULL OR vf.pbx_district = $2) \
           AND ($3::int     IS NULL OR (CURRENT_DATE - d.oldest_due_date) >= $3) \
           AND ($5::numeric IS NULL OR d.total_debt >= $5) \
           AND ($4::text IS NULL OR $4 = 'any' \
                OR ($4 = 'subscription' AND d.subscription_debt > 0) \
                OR ($4 = 'intercity'    AND d.intercity_debt > 0)) \
         ORDER BY d.total_debt DESC",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.district)
        .bind(p.min_days)
        .bind(p.kind)
        .bind(p.min_amount)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q4. PBX ranking by number of debtors / total debt (optionally by type).
#[derive(Deserialize)]
struct Q4 {
    pbx_type: Option<String>,
}

async fn q4_pbx_ranking(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q4>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT p.id AS pbx_id, p.name AS pbx_name, p.pbx_type::text AS pbx_type, \
                count(d.subscriber_id) AS debtors, \
                COALESCE(sum(d.total_debt), 0) AS debt_sum \
         FROM pbx p \
         LEFT JOIN phone_number pn ON pn.pbx_id = p.id \
         LEFT JOIN subscriber s ON s.phone_number_id = pn.id \
         LEFT JOIN v_subscriber_debt d ON d.subscriber_id = s.id AND d.total_debt > 0 \
         WHERE ($1::text IS NULL OR p.pbx_type::text = $1) \
         GROUP BY p.id \
         ORDER BY debt_sum DESC",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_type)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q9. City with the most intercity calls.
async fn q9_top_city(user: CurrentUser, State(st): State<AppState>) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT c.name AS city, count(*) AS calls \
         FROM call_record cr JOIN city c ON c.id = cr.dest_city_id \
         WHERE cr.call_type = 'intercity' \
         GROUP BY c.name ORDER BY calls DESC",
    );
    let (v,): (Value,) = sqlx::query_as(&sql).fetch_one(st.pool()).await?;
    Ok(Json(v))
}

/// Q10. Full information about subscribers with a given phone number.
#[derive(Deserialize)]
struct Q10 {
    number: String,
}

async fn q10_by_number(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q10>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap("SELECT * FROM v_subscriber_full WHERE number = $1");
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.number)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q5. Public phones and payphones (whole city / by PBX / by district / by kind).
#[derive(Deserialize)]
struct Q5 {
    pbx_id: Option<i64>,
    district: Option<String>,
    kind: Option<String>,
}

async fn q5_public_phones(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q5>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT pp.id, pp.kind::text AS kind, p.name AS pbx_name, \
                a.district, a.street, a.house, pp.active \
         FROM public_phone pp \
         JOIN pbx p ON p.id = pp.pbx_id \
         JOIN address a ON a.id = pp.address_id \
         WHERE ($1::bigint IS NULL OR pp.pbx_id = $1) \
           AND ($2::text   IS NULL OR a.district = $2) \
           AND ($3::text   IS NULL OR pp.kind::text = $3) \
         ORDER BY pp.kind, a.district, a.street",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.district)
        .bind(p.kind)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q6. Ratio of regular vs privileged subscribers (PBX / network / district / PBX type).
#[derive(Deserialize)]
struct Q6 {
    pbx_id: Option<i64>,
    district: Option<String>,
    pbx_type: Option<String>,
}

async fn q6_category_ratio(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q6>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT count(*) AS total, \
                count(*) FILTER (WHERE category = 'regular')    AS regular, \
                count(*) FILTER (WHERE category = 'privileged') AS privileged, \
                round(100.0 * count(*) FILTER (WHERE category = 'regular')    / NULLIF(count(*), 0), 2) AS regular_pct, \
                round(100.0 * count(*) FILTER (WHERE category = 'privileged') / NULLIF(count(*), 0), 2) AS privileged_pct \
         FROM v_subscriber_full \
         WHERE ($1::bigint IS NULL OR pbx_id = $1) \
           AND ($2::text   IS NULL OR district = $2) \
           AND ($3::text   IS NULL OR pbx_type::text = $3)",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.district)
        .bind(p.pbx_type)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q7. Subscribers with parallel phones (PBX / network / district / type; privileged only).
#[derive(Deserialize)]
struct Q7 {
    pbx_id: Option<i64>,
    district: Option<String>,
    pbx_type: Option<String>,
    privileged_only: Option<bool>,
}

async fn q7_parallel(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q7>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT * FROM v_subscriber_full \
         WHERE line_type = 'parallel' \
           AND ($1::bigint IS NULL OR pbx_id = $1) \
           AND ($2::text   IS NULL OR district = $2) \
           AND ($3::text   IS NULL OR pbx_type::text = $3) \
           AND ($4::bool   IS NULL OR $4 = false OR category = 'privileged') \
         ORDER BY number, last_name",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.district)
        .bind(p.pbx_type)
        .bind(p.privileged_only)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q8. Phones by address: counts per house / street, including intercity-capable ones.
#[derive(Deserialize)]
struct Q8 {
    district: Option<String>,
    street: Option<String>,
    house: Option<String>,
}

async fn q8_phones_by_address(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q8>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT a.district, a.street, a.house, \
                count(pn.id) AS phones, \
                count(pn.id) FILTER (WHERE pn.intercity IN ('open','closed')) AS with_intercity, \
                count(pn.id) FILTER (WHERE pn.intercity = 'open') AS with_open_intercity \
         FROM phone_number pn JOIN address a ON a.id = pn.address_id \
         WHERE ($1::text IS NULL OR a.district = $1) \
           AND ($2::text IS NULL OR a.street = $2) \
           AND ($3::text IS NULL OR a.house = $3) \
         GROUP BY a.district, a.street, a.house \
         ORDER BY a.district, a.street, a.house",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.district)
        .bind(p.street)
        .bind(p.house)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q11. Paired phones that can be split into separate numbers (free number + channel).
#[derive(Deserialize)]
struct Q11 {
    pbx_id: Option<i64>,
}

async fn q11_splittable(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q11>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT pn.id, pn.number, p.name AS pbx_name, p.district, \
                st.free_numbers, p.free_channels \
         FROM phone_number pn \
         JOIN pbx p ON p.id = pn.pbx_id \
         JOIN v_pbx_stats st ON st.pbx_id = p.id \
         WHERE pn.line_type = 'paired' \
           AND st.free_numbers > 0 AND p.free_channels > 0 \
           AND ($1::bigint IS NULL OR pn.pbx_id = $1) \
         ORDER BY pn.number",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q12. Internal numbers of closed-network PBXs with fewer than N external calls in a period.
#[derive(Deserialize)]
struct Q12 {
    pbx_id: Option<i64>,
    from: Option<String>,
    to: Option<String>,
    max_calls: Option<i64>,
}

async fn q12_low_external(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q12>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT pn.id, pn.number, p.name AS pbx_name, p.pbx_type::text AS pbx_type, \
                count(cr.id) AS external_calls \
         FROM phone_number pn \
         JOIN pbx p ON p.id = pn.pbx_id AND p.pbx_type IN ('departmental','institutional') \
         LEFT JOIN call_record cr ON cr.from_number_id = pn.id AND cr.call_type = 'external' \
              AND ($2::timestamptz IS NULL OR cr.started_at >= $2::timestamptz) \
              AND ($3::timestamptz IS NULL OR cr.started_at <  $3::timestamptz) \
         WHERE ($1::bigint IS NULL OR pn.pbx_id = $1) \
         GROUP BY pn.id, pn.number, p.name, p.pbx_type \
         HAVING count(cr.id) < $4 \
         ORDER BY external_calls, pn.number",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.from)
        .bind(p.to)
        .bind(p.max_calls.unwrap_or(i64::MAX))
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}

/// Q13. Debtors who should be notified / disconnected / have intercity blocked.
#[derive(Deserialize)]
struct Q13 {
    pbx_id: Option<i64>,
    district: Option<String>,
}

async fn q13_action_needed(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Q13>,
) -> AppResult<Json<Value>> {
    user.require(PERM)?;
    let sql = wrap(
        "SELECT vf.id, vf.last_name, vf.first_name, vf.number, vf.pbx_name, \
                vf.status, vf.intercity, \
                d.subscription_debt, d.intercity_debt, d.total_debt, \
                (d.subscription_debt > 0 AND NOT EXISTS ( \
                    SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id \
                    AND n.kind = 'subscription_debt' AND NOT n.resolved)) AS notice_subscription, \
                (d.intercity_debt > 0 AND NOT EXISTS ( \
                    SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id \
                    AND n.kind = 'intercity_debt' AND NOT n.resolved)) AS notice_intercity, \
                (d.subscription_debt > 0 AND vf.status <> 'disconnected' AND EXISTS ( \
                    SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id \
                    AND n.kind = 'subscription_debt' AND NOT n.resolved AND n.deadline < CURRENT_DATE)) AS should_disconnect, \
                (d.intercity_debt > 0 AND vf.intercity = 'open' AND EXISTS ( \
                    SELECT 1 FROM notification n WHERE n.subscriber_id = vf.id \
                    AND n.kind = 'intercity_debt' AND NOT n.resolved AND n.deadline < CURRENT_DATE)) AS should_block_intercity \
         FROM v_subscriber_debt d JOIN v_subscriber_full vf ON vf.id = d.subscriber_id \
         WHERE d.total_debt > 0 \
           AND ($1::bigint IS NULL OR vf.pbx_id = $1) \
           AND ($2::text   IS NULL OR vf.pbx_district = $2) \
         ORDER BY d.total_debt DESC",
    );
    let (v,): (Value,) = sqlx::query_as(&sql)
        .bind(p.pbx_id)
        .bind(p.district)
        .fetch_one(st.pool())
        .await?;
    Ok(Json(v))
}
