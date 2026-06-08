use std::sync::Arc;
use sea_orm::DatabaseConnection;
use crate::config::AppConfig;

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
    pub config: Arc<AppConfig>,
}

impl AppState {
    pub fn pool(&self) -> &sqlx::PgPool {
        self.db.get_postgres_connection_pool()
    }
}
