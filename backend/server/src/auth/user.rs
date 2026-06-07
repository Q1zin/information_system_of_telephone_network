//! Current authenticated user + permission set, loaded from the session.

use std::collections::HashSet;

use axum::extract::{FromRef, FromRequestParts};
use axum::http::request::Parts;
use serde::Serialize;
use tower_sessions::Session;

use crate::{
    error::{AppError, AppResult},
    state::AppState,
};

pub const USER_ID_KEY: &str = "user_id";

#[derive(Clone, Debug, Serialize)]
pub struct CurrentUser {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub is_superadmin: bool,
    pub permissions: HashSet<String>,
}

impl CurrentUser {
    /// Superadmin implicitly has every permission.
    pub fn has(&self, perm: &str) -> bool {
        self.is_superadmin || self.permissions.contains(perm)
    }

    pub fn require(&self, perm: &str) -> AppResult<()> {
        if self.has(perm) {
            Ok(())
        } else {
            Err(AppError::Forbidden)
        }
    }
}

/// Load a user and their effective permissions (via roles) from the database.
pub async fn load_current_user(
    pool: &sqlx::PgPool,
    user_id: i64,
) -> AppResult<Option<CurrentUser>> {
    let row = sqlx::query_as::<_, (i64, String, Option<String>, bool)>(
        "SELECT id, username, full_name, is_superadmin FROM app_user WHERE id = $1 AND is_active",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;

    let Some((id, username, full_name, is_superadmin)) = row else {
        return Ok(None);
    };

    let perms: Vec<(String,)> = sqlx::query_as(
        "SELECT DISTINCT p.code \
         FROM user_role ur \
         JOIN role_permission rp ON rp.role_id = ur.role_id \
         JOIN permission p ON p.id = rp.permission_id \
         WHERE ur.user_id = $1",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    Ok(Some(CurrentUser {
        id,
        username,
        full_name,
        is_superadmin,
        permissions: perms.into_iter().map(|(c,)| c).collect(),
    }))
}

impl<S> FromRequestParts<S> for CurrentUser
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let session = Session::from_request_parts(parts, state)
            .await
            .map_err(|_| AppError::Unauthorized)?;

        let user_id: Option<i64> = session
            .get(USER_ID_KEY)
            .await
            .map_err(|_| AppError::Unauthorized)?;
        let user_id = user_id.ok_or(AppError::Unauthorized)?;

        let app = AppState::from_ref(state);
        load_current_user(app.pool(), user_id)
            .await?
            .ok_or(AppError::Unauthorized)
    }
}
