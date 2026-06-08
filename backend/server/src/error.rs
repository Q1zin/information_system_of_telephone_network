use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

pub type AppResult<T> = Result<T, AppError>;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("resource not found")]
    NotFound,
    #[error("authentication required")]
    Unauthorized,
    #[error("access denied")]
    Forbidden,
    #[error("{0}")]
    BadRequest(String),
    #[error("{0}")]
    Conflict(String),
    #[error(transparent)]
    Db(#[from] sea_orm::DbErr),
    #[error(transparent)]
    Sqlx(#[from] sqlx::Error),
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl AppError {
    pub fn bad_request(msg: impl Into<String>) -> Self {
        AppError::BadRequest(msg.into())
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::NotFound => (StatusCode::NOT_FOUND, self.to_string()),
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, self.to_string()),
            AppError::Forbidden => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::BadRequest(_) => (StatusCode::BAD_REQUEST, self.to_string()),
            AppError::Conflict(_) => (StatusCode::CONFLICT, self.to_string()),
            AppError::Db(e) => map_db_err(e),
            AppError::Sqlx(e) => map_sqlx_err(e),
            AppError::Other(e) => {
                tracing::error!("internal error: {e:?}");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
            }
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}

fn map_db_err(e: &sea_orm::DbErr) -> (StatusCode, String) {
    if let sea_orm::DbErr::RecordNotFound(_) = e {
        return (StatusCode::NOT_FOUND, "resource not found".into());
    }
    if let Some(sqlx_err) = find_sqlx_error(e) {
        return map_sqlx_err(sqlx_err);
    }
    tracing::error!("db error: {e:?}");
    (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
}

fn find_sqlx_error(e: &sea_orm::DbErr) -> Option<&sqlx::Error> {
    match e {
        sea_orm::DbErr::Query(sea_orm::RuntimeErr::SqlxError(e))
        | sea_orm::DbErr::Exec(sea_orm::RuntimeErr::SqlxError(e))
        | sea_orm::DbErr::Conn(sea_orm::RuntimeErr::SqlxError(e)) => Some(e),
        _ => None,
    }
}

fn map_sqlx_err(e: &sqlx::Error) -> (StatusCode, String) {
    if let sqlx::Error::Database(db) = e {
        let code = db.code().unwrap_or_default();
        let msg = db.message().to_string();
        return match code.as_ref() {
            // unique_violation
            "23505" => (StatusCode::CONFLICT, friendly(&msg, "duplicate value")),
            // foreign_key_violation
            "23503" => (
                StatusCode::CONFLICT,
                friendly(&msg, "referenced/related record prevents this operation"),
            ),
            // not_null / check / exclusion violations
            "23502" | "23514" | "23P01" => (StatusCode::BAD_REQUEST, msg),
            // raise_exception (our triggers)
            "P0001" => (StatusCode::BAD_REQUEST, msg),
            _ => {
                tracing::error!("database error [{code}]: {msg}");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
            }
        };
    }
    tracing::error!("sqlx error: {e:?}");
    (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
}

fn friendly(raw: &str, fallback: &str) -> String {
    if raw.is_empty() {
        fallback.to_string()
    } else {
        raw.to_string()
    }
}
