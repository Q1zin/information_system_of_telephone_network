//! First-run bootstrap of the superadmin account.

use crate::{auth::password::hash_password, config::AuthConfig};

pub async fn ensure_superadmin(pool: &sqlx::PgPool, cfg: &AuthConfig) -> anyhow::Result<()> {
    let existing: Option<(i64,)> =
        sqlx::query_as("SELECT id FROM app_user WHERE username = $1")
            .bind(&cfg.superadmin_username)
            .fetch_optional(pool)
            .await?;
    if existing.is_some() {
        return Ok(());
    }

    let hash = hash_password(&cfg.superadmin_password)?;
    let (uid,): (i64,) = sqlx::query_as(
        "INSERT INTO app_user (username, password_hash, full_name, is_superadmin, is_active) \
         VALUES ($1, $2, 'Super Admin', TRUE, TRUE) RETURNING id",
    )
    .bind(&cfg.superadmin_username)
    .bind(&hash)
    .fetch_one(pool)
    .await?;

    // Attach the seeded 'superadmin' role, if present.
    sqlx::query(
        "INSERT INTO user_role (user_id, role_id) \
         SELECT $1, id FROM role WHERE name = 'superadmin' ON CONFLICT DO NOTHING",
    )
    .bind(uid)
    .execute(pool)
    .await?;

    tracing::info!("bootstrapped superadmin user '{}'", cfg.superadmin_username);
    Ok(())
}
