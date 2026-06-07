//! Database connection setup (SeaORM connection; the underlying sqlx pool is
//! reused for raw analytical/user queries via `conn.get_postgres_connection_pool()`).

use std::time::Duration;

use sea_orm::{ConnectOptions, Database, DatabaseConnection};

use crate::config::DatabaseConfig;

pub async fn connect(cfg: &DatabaseConfig) -> anyhow::Result<DatabaseConnection> {
    let mut opt = ConnectOptions::new(cfg.url());
    opt.max_connections(cfg.max_connections)
        .acquire_timeout(Duration::from_secs(8))
        .sqlx_logging_level(tracing::log::LevelFilter::Debug);
    let db = Database::connect(opt).await?;
    Ok(db)
}
