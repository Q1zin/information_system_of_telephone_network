//! Serde default helpers for server-managed columns. The values are only used
//! to let partial JSON payloads deserialize into a full `Model`; columns absent
//! from the request are not written, so the database DEFAULT applies.

use sea_orm::prelude::{Date, DateTimeWithTimeZone};

pub fn today() -> Date {
    chrono::Utc::now().date_naive()
}

pub fn now_tz() -> DateTimeWithTimeZone {
    chrono::Utc::now().into()
}
