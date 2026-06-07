//! Admin / RBAC management endpoints (req. 7). Roles and permissions are stored
//! in the database, so a superadmin can reconfigure access without code changes.

use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};

use crate::{
    auth::{password::hash_password, CurrentUser},
    error::{AppError, AppResult},
    state::AppState,
};

fn wrap(inner: &str) -> String {
    format!("SELECT coalesce(json_agg(row_to_json(q)), '[]'::json) FROM ({inner}) q")
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/permissions", get(list_permissions))
        .route("/roles", get(list_roles).post(create_role))
        .route("/roles/{id}", axum::routing::put(update_role).delete(delete_role))
        .route("/roles/{id}/permissions", post(set_role_permissions))
        .route("/users", get(list_users).post(create_user))
        .route("/users/{id}", axum::routing::put(update_user).delete(delete_user))
        .route("/users/{id}/roles", post(set_user_roles))
}

// ---------------------------------------------------------------- permissions

async fn list_permissions(user: CurrentUser, State(st): State<AppState>) -> AppResult<Json<Value>> {
    user.require("role:read")?;
    let (v,): (Value,) =
        sqlx::query_as(&wrap("SELECT id, code, description FROM permission ORDER BY code"))
            .fetch_one(st.pool())
            .await?;
    Ok(Json(v))
}

// ----------------------------------------------------------------------- roles

async fn list_roles(user: CurrentUser, State(st): State<AppState>) -> AppResult<Json<Value>> {
    user.require("role:read")?;
    let (v,): (Value,) = sqlx::query_as(&wrap(
        "SELECT r.id, r.name, r.description, r.is_system, \
                COALESCE(array_agg(p.code) FILTER (WHERE p.code IS NOT NULL), '{}') AS permissions \
         FROM role r \
         LEFT JOIN role_permission rp ON rp.role_id = r.id \
         LEFT JOIN permission p ON p.id = rp.permission_id \
         GROUP BY r.id ORDER BY r.id",
    ))
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

#[derive(Deserialize)]
struct RoleInput {
    name: String,
    description: Option<String>,
}

async fn create_role(
    user: CurrentUser,
    State(st): State<AppState>,
    Json(input): Json<RoleInput>,
) -> AppResult<Json<Value>> {
    user.require("role:create")?;
    let (id,): (i64,) = sqlx::query_as(
        "INSERT INTO role (name, description, is_system) VALUES ($1, $2, FALSE) RETURNING id",
    )
    .bind(&input.name)
    .bind(&input.description)
    .fetch_one(st.pool())
    .await?;
    Ok(Json(json!({ "id": id })))
}

async fn update_role(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
    Json(input): Json<RoleInput>,
) -> AppResult<Json<Value>> {
    user.require("role:update")?;
    let res = sqlx::query("UPDATE role SET name = $2, description = $3 WHERE id = $1")
        .bind(id)
        .bind(&input.name)
        .bind(&input.description)
        .execute(st.pool())
        .await?;
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound);
    }
    Ok(Json(json!({ "id": id })))
}

async fn delete_role(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
) -> AppResult<Json<Value>> {
    user.require("role:delete")?;
    let is_system: Option<(bool,)> = sqlx::query_as("SELECT is_system FROM role WHERE id = $1")
        .bind(id)
        .fetch_optional(st.pool())
        .await?;
    match is_system {
        None => return Err(AppError::NotFound),
        Some((true,)) => return Err(AppError::bad_request("system roles cannot be deleted")),
        Some((false,)) => {}
    }
    sqlx::query("DELETE FROM role WHERE id = $1")
        .bind(id)
        .execute(st.pool())
        .await?;
    Ok(Json(json!({ "deleted": id })))
}

#[derive(Deserialize)]
struct PermissionIds {
    permission_ids: Vec<i64>,
}

async fn set_role_permissions(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
    Json(input): Json<PermissionIds>,
) -> AppResult<Json<Value>> {
    user.require("rbac:manage")?;
    let mut tx = st.pool().begin().await?;
    sqlx::query("DELETE FROM role_permission WHERE role_id = $1")
        .bind(id)
        .execute(&mut *tx)
        .await?;
    sqlx::query(
        "INSERT INTO role_permission (role_id, permission_id) \
         SELECT $1, unnest($2::bigint[]) ON CONFLICT DO NOTHING",
    )
    .bind(id)
    .bind(&input.permission_ids)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(Json(json!({ "role_id": id, "permissions": input.permission_ids.len() })))
}

// ----------------------------------------------------------------------- users

async fn list_users(user: CurrentUser, State(st): State<AppState>) -> AppResult<Json<Value>> {
    user.require("user:read")?;
    let (v,): (Value,) = sqlx::query_as(&wrap(
        "SELECT u.id, u.username, u.full_name, u.is_superadmin, u.is_active, \
                u.created_at, u.last_login_at, \
                COALESCE(array_agg(r.name) FILTER (WHERE r.name IS NOT NULL), '{}') AS roles \
         FROM app_user u \
         LEFT JOIN user_role ur ON ur.user_id = u.id \
         LEFT JOIN role r ON r.id = ur.role_id \
         GROUP BY u.id ORDER BY u.id",
    ))
    .fetch_one(st.pool())
    .await?;
    Ok(Json(v))
}

#[derive(Deserialize)]
struct CreateUser {
    username: String,
    password: String,
    full_name: Option<String>,
    #[serde(default)]
    is_superadmin: bool,
    #[serde(default)]
    role_ids: Vec<i64>,
}

async fn create_user(
    user: CurrentUser,
    State(st): State<AppState>,
    Json(input): Json<CreateUser>,
) -> AppResult<Json<Value>> {
    user.require("user:create")?;
    if input.password.len() < 4 {
        return Err(AppError::bad_request("password must be at least 4 characters"));
    }
    let hash = hash_password(&input.password)?;
    let mut tx = st.pool().begin().await?;
    let (id,): (i64,) = sqlx::query_as(
        "INSERT INTO app_user (username, password_hash, full_name, is_superadmin, is_active) \
         VALUES ($1, $2, $3, $4, TRUE) RETURNING id",
    )
    .bind(&input.username)
    .bind(&hash)
    .bind(&input.full_name)
    .bind(input.is_superadmin)
    .fetch_one(&mut *tx)
    .await?;
    sqlx::query(
        "INSERT INTO user_role (user_id, role_id) \
         SELECT $1, unnest($2::bigint[]) ON CONFLICT DO NOTHING",
    )
    .bind(id)
    .bind(&input.role_ids)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(Json(json!({ "id": id })))
}

#[derive(Deserialize)]
struct UpdateUser {
    full_name: Option<String>,
    is_active: Option<bool>,
    is_superadmin: Option<bool>,
    password: Option<String>,
}

async fn update_user(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
    Json(input): Json<UpdateUser>,
) -> AppResult<Json<Value>> {
    user.require("user:update")?;
    // COALESCE keeps existing values when a field is omitted.
    let password_hash = match input.password {
        Some(ref p) if !p.is_empty() => Some(hash_password(p)?),
        _ => None,
    };
    let res = sqlx::query(
        "UPDATE app_user SET \
            full_name = COALESCE($2, full_name), \
            is_active = COALESCE($3, is_active), \
            is_superadmin = COALESCE($4, is_superadmin), \
            password_hash = COALESCE($5, password_hash) \
         WHERE id = $1",
    )
    .bind(id)
    .bind(&input.full_name)
    .bind(input.is_active)
    .bind(input.is_superadmin)
    .bind(&password_hash)
    .execute(st.pool())
    .await?;
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound);
    }
    Ok(Json(json!({ "id": id })))
}

async fn delete_user(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
) -> AppResult<Json<Value>> {
    user.require("user:delete")?;
    if id == user.id {
        return Err(AppError::bad_request("you cannot delete your own account"));
    }
    let res = sqlx::query("DELETE FROM app_user WHERE id = $1")
        .bind(id)
        .execute(st.pool())
        .await?;
    if res.rows_affected() == 0 {
        return Err(AppError::NotFound);
    }
    Ok(Json(json!({ "deleted": id })))
}

#[derive(Deserialize)]
struct RoleIds {
    role_ids: Vec<i64>,
}

async fn set_user_roles(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
    Json(input): Json<RoleIds>,
) -> AppResult<Json<Value>> {
    user.require("rbac:manage")?;
    let mut tx = st.pool().begin().await?;
    sqlx::query("DELETE FROM user_role WHERE user_id = $1")
        .bind(id)
        .execute(&mut *tx)
        .await?;
    sqlx::query(
        "INSERT INTO user_role (user_id, role_id) \
         SELECT $1, unnest($2::bigint[]) ON CONFLICT DO NOTHING",
    )
    .bind(id)
    .bind(&input.role_ids)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(Json(json!({ "user_id": id, "roles": input.role_ids.len() })))
}
