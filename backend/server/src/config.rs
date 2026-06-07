//! Application configuration (req. 5).
//!
//! Values are read from `config.toml` and can be overridden by environment
//! variables prefixed with `GTS__` (e.g. `GTS__DATABASE__PASSWORD=secret`).

use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct DatabaseConfig {
    pub host: String,
    pub port: u16,
    pub user: String,
    pub password: String,
    pub name: String,
    #[serde(default = "default_max_connections")]
    pub max_connections: u32,
}

fn default_max_connections() -> u32 {
    10
}

impl DatabaseConfig {
    pub fn url(&self) -> String {
        format!(
            "postgres://{}:{}@{}:{}/{}",
            self.user, self.password, self.host, self.port, self.name
        )
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
}

impl ServerConfig {
    pub fn bind_addr(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct AuthConfig {
    pub session_secret: String,
    pub superadmin_username: String,
    pub superadmin_password: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AppConfig {
    pub database: DatabaseConfig,
    pub server: ServerConfig,
    pub auth: AuthConfig,
}

impl AppConfig {
    /// Load configuration from `config.toml` + `GTS__*` environment overrides.
    pub fn load() -> anyhow::Result<Self> {
        // .env is optional; used mainly for tooling (sqlx/sea-orm-cli).
        let _ = dotenvy::dotenv();

        let cfg = config::Config::builder()
            .add_source(config::File::with_name("config").required(false))
            .add_source(
                config::Environment::with_prefix("GTS")
                    .prefix_separator("__")
                    .separator("__")
                    .try_parsing(true),
            )
            .build()?;

        Ok(cfg.try_deserialize()?)
    }
}
