use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

pub type AppResult<T> = Result<T, AppError>;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Запись не найдена")]
    NotFound,
    #[error("Требуется авторизация")]
    Unauthorized,
    #[error("Неверный логин или пароль")]
    InvalidCredentials,
    #[error("Доступ запрещён")]
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
            AppError::InvalidCredentials => (StatusCode::UNAUTHORIZED, self.to_string()),
            AppError::Forbidden => (StatusCode::FORBIDDEN, self.to_string()),
            AppError::BadRequest(_) => (StatusCode::BAD_REQUEST, self.to_string()),
            AppError::Conflict(_) => (StatusCode::CONFLICT, self.to_string()),
            AppError::Db(e) => map_db_err(e),
            AppError::Sqlx(e) => map_sqlx_err(e),
            AppError::Other(e) => {
                tracing::error!("internal error: {e:?}");
                (StatusCode::INTERNAL_SERVER_ERROR, INTERNAL.into())
            }
        };
        (status, Json(json!({ "error": message }))).into_response()
    }
}

const INTERNAL: &str = "Внутренняя ошибка сервера";

fn map_db_err(e: &sea_orm::DbErr) -> (StatusCode, String) {
    if let sea_orm::DbErr::RecordNotFound(_) = e {
        return (StatusCode::NOT_FOUND, "Запись не найдена".into());
    }
    if let Some(sqlx_err) = find_sqlx_error(e) {
        return map_sqlx_err(sqlx_err);
    }
    tracing::error!("db error: {e:?}");
    (StatusCode::INTERNAL_SERVER_ERROR, INTERNAL.into())
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
        let raw = db.message().to_string();
        return match code.as_ref() {
            // unique_violation
            "23505" => (
                StatusCode::CONFLICT,
                "Запись с такими данными уже существует — значение должно быть уникальным".into(),
            ),
            // foreign_key_violation
            "23503" => {
                let msg = if raw.contains("is still referenced from") {
                    "Нельзя удалить или изменить запись: на неё ссылаются другие записи"
                } else {
                    "Указанная связанная запись не существует"
                };
                (StatusCode::CONFLICT, msg.into())
            }
            // not_null_violation
            "23502" => {
                let msg = match column_in_quotes(&raw) {
                    Some(col) => format!("Не заполнено обязательное поле: «{}»", field_label(&col)),
                    None => "Не заполнено обязательное поле".into(),
                };
                (StatusCode::BAD_REQUEST, msg)
            }
            // check_violation
            "23514" => (
                StatusCode::BAD_REQUEST,
                "Значение не соответствует ограничениям (проверка данных не пройдена)".into(),
            ),
            // exclusion_violation
            "23P01" => (
                StatusCode::BAD_REQUEST,
                "Значение конфликтует с уже существующими данными".into(),
            ),
            // invalid_text_representation (e.g. bad enum value)
            "22P02" => (
                StatusCode::BAD_REQUEST,
                "Недопустимое значение одного из полей".into(),
            ),
            // raise_exception from our triggers — already a human-readable (Russian) message
            "P0001" => (StatusCode::BAD_REQUEST, raw),
            _ => {
                tracing::error!("database error [{code}]: {raw}");
                (StatusCode::INTERNAL_SERVER_ERROR, INTERNAL.into())
            }
        };
    }
    tracing::error!("sqlx error: {e:?}");
    (StatusCode::INTERNAL_SERVER_ERROR, INTERNAL.into())
}

/// Extracts the first `"..."`-quoted identifier following `column ` in a
/// Postgres error message (e.g. `... column "first_name" ...` -> `first_name`).
fn column_in_quotes(msg: &str) -> Option<String> {
    let after = msg.split("column \"").nth(1)?;
    after.split('"').next().map(str::to_string)
}

/// Maps a database column name to a Russian label for user-facing messages,
/// falling back to the raw column name when unknown.
fn field_label(col: &str) -> String {
    let label = match col {
        "last_name" | "applicant_last_name" => "Фамилия",
        "first_name" | "applicant_first_name" => "Имя",
        "middle_name" | "applicant_middle_name" => "Отчество",
        "birth_date" => "Дата рождения",
        "gender" => "Пол",
        "name" => "Название",
        "code" => "Код",
        "number" => "Номер",
        "login" | "username" => "Логин",
        "full_name" => "Полное имя",
        "amount" => "Сумма",
        "monthly_fee" => "Абонплата",
        "due_date" => "Срок оплаты",
        "period_year" => "Год",
        "period_month" => "Месяц",
        "pbx_id" => "АТС",
        "desired_pbx_id" => "Желаемая АТС",
        "address_id" => "Адрес",
        "subscriber_id" => "Абонент",
        "phone_number_id" => "Номер",
        "from_number_id" => "Номер-источник",
        "dest_city_id" => "Город",
        "invoice_id" => "Счёт",
        "district" => "Район",
        "street" => "Улица",
        "house" => "Дом",
        "apartment" => "Квартира",
        "postal_index" => "Индекс",
        "capacity_numbers" => "Ёмкость номеров",
        "total_channels" => "Всего каналов",
        "free_channels" => "Свободно каналов",
        "department_name" => "Ведомство",
        "institution_name" => "Учреждение",
        "started_at" => "Начало",
        "duration_sec" => "Длительность",
        "deadline" => "Дедлайн",
        "reason" => "Причина",
        _ => return col.to_string(),
    };
    label.to_string()
}
