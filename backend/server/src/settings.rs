use axum::{extract::State, routing::get, Json, Router};
use serde::Deserialize;
use serde_json::Value;
use crate::{auth::CurrentUser, error::AppResult, state::AppState};

pub fn router() -> Router<AppState> {
    Router::new().route("/", get(get_settings).put(update_settings))
}

async fn fetch(pool: &sqlx::PgPool) -> AppResult<Value> {
    let (v,): (Value,) =
        sqlx::query_as("SELECT row_to_json(b) FROM billing_settings b WHERE id = 1")
            .fetch_one(pool)
            .await?;
    Ok(v)
}

async fn get_settings(user: CurrentUser, State(st): State<AppState>) -> AppResult<Json<Value>> {
    user.require("billing_settings:read")?;
    Ok(Json(fetch(st.pool()).await?))
}

#[derive(Deserialize)]
struct SettingsInput {
    privilege_discount: Option<f64>,
    reconnection_fee: Option<f64>,
    penalty_daily_rate: Option<f64>,
    payment_due_day: Option<i16>,
    notice_grace_days: Option<i16>,
}

async fn update_settings(
    user: CurrentUser,
    State(st): State<AppState>,
    Json(input): Json<SettingsInput>,
) -> AppResult<Json<Value>> {
    user.require("billing_settings:update")?;
    sqlx::query(
        "UPDATE billing_settings SET \
            privilege_discount = COALESCE($1::numeric, privilege_discount), \
            reconnection_fee   = COALESCE($2::numeric, reconnection_fee), \
            penalty_daily_rate = COALESCE($3::numeric, penalty_daily_rate), \
            payment_due_day    = COALESCE($4::smallint, payment_due_day), \
            notice_grace_days  = COALESCE($5::smallint, notice_grace_days) \
         WHERE id = 1",
    )
    .bind(input.privilege_discount)
    .bind(input.reconnection_fee)
    .bind(input.penalty_daily_rate)
    .bind(input.payment_due_day)
    .bind(input.notice_grace_days)
    .execute(st.pool())
    .await?;
    Ok(Json(fetch(st.pool()).await?))
}
