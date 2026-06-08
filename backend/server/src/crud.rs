use axum::{
    extract::{Path, Query, State},
    routing::get,
    Json, Router,
};
use sea_orm::{
    ActiveModelBehavior, ActiveModelTrait, EntityTrait, IdenStatic, IntoActiveModel, Iterable,
    PaginatorTrait, PrimaryKeyToColumn, PrimaryKeyTrait, QueryOrder,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use crate::{
    auth::CurrentUser,
    error::{AppError, AppResult},
    state::AppState,
};

pub trait Resource: EntityTrait {
    const NAME: &'static str;
}

#[derive(Debug, Deserialize)]
pub struct Pagination {
    #[serde(default = "default_page")]
    pub page: u64,
    #[serde(default = "default_page_size")]
    pub page_size: u64,
}
fn default_page() -> u64 {
    1
}
fn default_page_size() -> u64 {
    20
}

#[derive(Serialize)]
pub struct Page<T> {
    pub items: Vec<T>,
    pub total: u64,
    pub page: u64,
    pub page_size: u64,
    pub total_pages: u64,
}

pub fn crud_routes<E>() -> Router<AppState>
where
    E: Resource + 'static,
    E::Model: Serialize + Send + Sync + IntoActiveModel<E::ActiveModel> + for<'de> Deserialize<'de>,
    E::ActiveModel: ActiveModelTrait<Entity = E> + ActiveModelBehavior + Send + Sync + Default,
    E::PrimaryKey: PrimaryKeyToColumn<Column = E::Column> + PrimaryKeyTrait<ValueType = i64>,
{
    Router::new()
        .route("/", get(list::<E>).post(create::<E>))
        .route("/{id}", get(get_one::<E>).put(update::<E>).delete(delete::<E>))
}

async fn list<E>(
    user: CurrentUser,
    State(st): State<AppState>,
    Query(p): Query<Pagination>,
) -> AppResult<Json<Page<E::Model>>>
where
    E: Resource,
    E::Model: Serialize + Send + Sync,
    E::PrimaryKey: PrimaryKeyToColumn<Column = E::Column>,
{
    user.require(&format!("{}:read", E::NAME))?;
    let page = p.page.max(1);
    let page_size = p.page_size.clamp(1, 200);

    let mut select = E::find();
    for pk in E::PrimaryKey::iter() {
        select = select.order_by_asc(pk.into_column());
    }
    let paginator = select.paginate(&st.db, page_size);
    let total = paginator.num_items().await?;
    let total_pages = paginator.num_pages().await?;
    let items = paginator.fetch_page(page - 1).await?;

    Ok(Json(Page {
        items,
        total,
        page,
        page_size,
        total_pages,
    }))
}

async fn get_one<E>(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
) -> AppResult<Json<E::Model>>
where
    E: Resource,
    E::Model: Serialize + Send + Sync,
    E::PrimaryKey: PrimaryKeyTrait<ValueType = i64>,
{
    user.require(&format!("{}:read", E::NAME))?;
    let model = E::find_by_id(id)
        .one(&st.db)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(model))
}

async fn create<E>(
    user: CurrentUser,
    State(st): State<AppState>,
    Json(payload): Json<Value>,
) -> AppResult<Json<E::Model>>
where
    E: Resource,
    E::Model: Serialize + Send + Sync + IntoActiveModel<E::ActiveModel> + for<'de> Deserialize<'de>,
    E::ActiveModel: ActiveModelTrait<Entity = E> + ActiveModelBehavior + Send + Sync + Default,
    E::PrimaryKey: PrimaryKeyToColumn<Column = E::Column> + PrimaryKeyTrait,
{
    user.require(&format!("{}:create", E::NAME))?;
    let mut am = <E::ActiveModel as std::default::Default>::default();
    am.set_from_json(payload.clone())?;
    
    if !E::PrimaryKey::auto_increment() {
        for pk in E::PrimaryKey::iter() {
            let col = pk.into_column();
            if let Some(v) = payload.get(col.as_str()).and_then(|x| x.as_i64()) {
                am.set(col, v.into());
            }
        }
    }
    let model = am.insert(&st.db).await?;
    Ok(Json(model))
}

async fn update<E>(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
    Json(payload): Json<Value>,
) -> AppResult<Json<E::Model>>
where
    E: Resource,
    E::Model: Serialize + Send + Sync + IntoActiveModel<E::ActiveModel> + for<'de> Deserialize<'de>,
    E::ActiveModel: ActiveModelTrait<Entity = E> + ActiveModelBehavior + Send + Sync,
    E::PrimaryKey: PrimaryKeyTrait<ValueType = i64>,
{
    user.require(&format!("{}:update", E::NAME))?;
    let existing = E::find_by_id(id)
        .one(&st.db)
        .await?
        .ok_or(AppError::NotFound)?;
    let mut am = existing.into_active_model();
    am.set_from_json(payload)?;
    let model = am.update(&st.db).await?;
    Ok(Json(model))
}

async fn delete<E>(
    user: CurrentUser,
    State(st): State<AppState>,
    Path(id): Path<i64>,
) -> AppResult<Json<Value>>
where
    E: Resource,
    E::PrimaryKey: PrimaryKeyTrait<ValueType = i64>,
{
    user.require(&format!("{}:delete", E::NAME))?;
    let res = E::delete_by_id(id).exec(&st.db).await?;
    if res.rows_affected == 0 {
        return Err(AppError::NotFound);
    }
    Ok(Json(serde_json::json!({ "deleted": id })))
}
