use axum::{extract::State, routing::post, Json, Router};
use serde::Deserialize;
use serde_json::Value;
use crate::{
    auth::CurrentUser,
    error::{AppError, AppResult},
    state::AppState,
};

pub fn router() -> Router<AppState> {
    Router::new().route("/", post(run))
}

#[derive(Deserialize)]
struct RawQuery {
    sql: String,
}

async fn run(
    user: CurrentUser,
    State(st): State<AppState>,
    Json(input): Json<RawQuery>,
) -> AppResult<Json<Value>> {
    user.require("raw_query:run")?;

    let trimmed = input.sql.trim().trim_end_matches(';').trim().to_string();
    let lower = trimmed.to_lowercase();
    if !(lower.starts_with("select") || lower.starts_with("with")) {
        return Err(AppError::bad_request(
            "Разрешён только запрос на чтение (SELECT/WITH)",
        ));
    }
    if trimmed.contains(';') {
        return Err(AppError::bad_request("Нельзя выполнять несколько запросов сразу"));
    }

    let wrapped = format!(
        "SELECT coalesce(json_agg(row_to_json(q)), '[]'::json) FROM ({trimmed}) q"
    );

    let mut tx = st.pool().begin().await?;
    sqlx::query("SET TRANSACTION READ ONLY")
        .execute(&mut *tx)
        .await?;
    sqlx::query("SET LOCAL statement_timeout = '5000'")
        .execute(&mut *tx)
        .await?;
    let result = sqlx::query_as::<_, (Value,)>(&wrapped)
        .fetch_one(&mut *tx)
        .await;
    let _ = tx.rollback().await;

    let (v,) = result?;
    Ok(Json(v))
}
