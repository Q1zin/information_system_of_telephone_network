use axum::{
    extract::State,
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use tower_sessions::Session;
use crate::{
    auth::{
        password::verify_password,
        user::{load_current_user, CurrentUser, USER_ID_KEY},
    },
    error::{AppError, AppResult},
    state::AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/login", post(login))
        .route("/logout", post(logout))
        .route("/me", get(me))
}

#[derive(Deserialize)]
struct LoginInput {
    username: String,
    password: String,
}

async fn login(
    State(st): State<AppState>,
    session: Session,
    Json(input): Json<LoginInput>,
) -> AppResult<Json<CurrentUser>> {
    let row = sqlx::query_as::<_, (i64, String)>(
        "SELECT id, password_hash FROM app_user WHERE username = $1 AND is_active",
    )
    .bind(&input.username)
    .fetch_optional(st.pool())
    .await?;

    let Some((id, hash)) = row else {
        return Err(AppError::InvalidCredentials);
    };
    if !verify_password(&input.password, &hash) {
        return Err(AppError::InvalidCredentials);
    }

    session
        .insert(USER_ID_KEY, id)
        .await
        .map_err(|e| AppError::Other(anyhow::anyhow!("session error: {e}")))?;
    sqlx::query("UPDATE app_user SET last_login_at = now() WHERE id = $1")
        .bind(id)
        .execute(st.pool())
        .await?;

    let user = load_current_user(st.pool(), id)
        .await?
        .ok_or(AppError::Unauthorized)?;
    Ok(Json(user))
}

async fn logout(session: Session) -> AppResult<Json<Value>> {
    session
        .flush()
        .await
        .map_err(|e| AppError::Other(anyhow::anyhow!("session error: {e}")))?;
    Ok(Json(json!({ "status": "ok" })))
}

async fn me(user: CurrentUser) -> Json<CurrentUser> {
    Json(user)
}
