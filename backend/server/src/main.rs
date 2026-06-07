mod admin;
mod analytics;
mod auth;
mod config;
mod crud;
mod db;
mod error;
mod raw_query;
mod resources;
mod state;

use std::sync::Arc;

use axum::{
    http::{header, HeaderValue, Method},
    routing::get,
    Json, Router,
};
use serde_json::{json, Value};
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tower_sessions::{Expiry, SessionManagerLayer};
use tower_sessions_sqlx_store::PostgresStore;

use crate::{config::AppConfig, state::AppState};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,sqlx=warn,tower_http=info".into()),
        )
        .init();

    let config = AppConfig::load()?;
    tracing::info!("connecting to database at {}", config.database.host);
    let db = db::connect(&config.database).await?;

    // Session store on the same Postgres database.
    let session_store = PostgresStore::new(db.get_postgres_connection_pool().clone());
    session_store.migrate().await?;
    let session_layer = SessionManagerLayer::new(session_store)
        .with_secure(false)
        .with_expiry(Expiry::OnInactivity(time::Duration::days(7)));

    // Create the bootstrap superadmin if needed.
    auth::bootstrap::ensure_superadmin(db.get_postgres_connection_pool(), &config.auth).await?;

    let bind_addr = config.server.bind_addr();
    let state = AppState {
        db,
        config: Arc::new(config),
    };

    // CORS for the Vue dev server (credentials require an explicit origin).
    let cors = CorsLayer::new()
        .allow_origin("http://localhost:5173".parse::<HeaderValue>().unwrap())
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([header::CONTENT_TYPE])
        .allow_credentials(true);

    let api = Router::new()
        .nest("/auth", auth::routes::router())
        .nest("/admin", admin::router())
        .nest("/analytics", analytics::router())
        .nest("/raw-query", raw_query::router())
        .merge(resources::api_router());

    let app = Router::new()
        .route("/health", get(health))
        .nest("/api", api)
        .layer(session_layer)
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&bind_addr).await?;
    tracing::info!("listening on http://{bind_addr}");
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health() -> Json<Value> {
    Json(json!({ "status": "ok" }))
}
