#![allow(dead_code)]

use serde_json::Value;
use utoipa::{
    openapi::security::{ApiKey, ApiKeyValue, SecurityScheme},
    Modify, OpenApi, ToSchema,
};

#[derive(ToSchema)]
struct LoginRequest {
    #[schema(example = "admin")]
    username: String,
    #[schema(example = "admin")]
    password: String,
}

#[derive(ToSchema)]
struct UserResponse {
    id: i64,
    username: String,
    full_name: Option<String>,
    is_superadmin: bool,
    permissions: Vec<String>,
}

#[derive(ToSchema)]
struct ErrorResponse {
    error: String,
}

#[derive(ToSchema)]
struct StatusResponse {
    status: String,
}

#[derive(ToSchema)]
struct CrudPage {
    items: Vec<Value>,
    total: u64,
    page: u64,
    page_size: u64,
    total_pages: u64,
}

#[derive(ToSchema)]
struct RoleInput {
    name: String,
    description: Option<String>,
}

#[derive(ToSchema)]
struct PermissionIdsInput {
    permission_ids: Vec<i64>,
}

#[derive(ToSchema)]
struct RoleIdsInput {
    role_ids: Vec<i64>,
}

#[derive(ToSchema)]
struct CreateUserInput {
    username: String,
    password: String,
    full_name: Option<String>,
    is_superadmin: Option<bool>,
    role_ids: Option<Vec<i64>>,
}

#[derive(ToSchema)]
struct UpdateUserInput {
    full_name: Option<String>,
    is_active: Option<bool>,
    is_superadmin: Option<bool>,
    password: Option<String>,
}

#[derive(ToSchema)]
struct RawQueryInput {
    #[schema(example = "SELECT * FROM v_subscriber_full LIMIT 20")]
    sql: String,
}

#[derive(ToSchema)]
struct CustomerRegister {
    login: String,
    password: String,
    last_name: String,
    first_name: String,
    middle_name: Option<String>,
    gender: String,
    birth_date: String,
    category: Option<String>,
    privilege: Option<String>,
}

#[derive(ToSchema)]
struct CustomerLogin {
    login: String,
    password: String,
}

#[derive(ToSchema)]
struct ApplyInput {
    postal_index: String,
    district: String,
    street: String,
    house: String,
    apartment: Option<String>,
    desired_pbx_id: Option<i64>,
}

#[derive(ToSchema)]
struct IntercityInput {
    enabled: bool,
}

#[derive(ToSchema)]
struct CallInput {
    kind: String,
    dest_number: Option<String>,
    dest_city_id: Option<i64>,
    duration_sec: Option<i32>,
}

#[derive(ToSchema)]
struct ProvisionInput {
    pbx_id: Option<i64>,
    line_type: Option<String>,
}

#[utoipa::path(
    post, path = "/api/auth/login", tag = "auth",
    request_body = LoginRequest,
    responses(
        (status = 200, description = "Authenticated; session cookie set", body = UserResponse),
        (status = 401, description = "Invalid credentials", body = ErrorResponse),
    )
)]
fn auth_login() {}

#[utoipa::path(post, path = "/api/auth/logout", tag = "auth",
    responses((status = 200, body = StatusResponse)))]
fn auth_logout() {}

#[utoipa::path(get, path = "/api/auth/me", tag = "auth",
    responses(
        (status = 200, body = UserResponse),
        (status = 401, body = ErrorResponse),
    ))]
fn auth_me() {}

#[utoipa::path(
    get, path = "/api/{resource}", tag = "crud",
    params(
        ("resource" = String, Path, description = "Resource path segment"),
        ("page" = Option<u64>, Query, description = "1-based page number"),
        ("page_size" = Option<u64>, Query, description = "Items per page (max 200)"),
    ),
    responses((status = 200, body = CrudPage), (status = 403, body = ErrorResponse))
)]
fn crud_list() {}

#[utoipa::path(
    post, path = "/api/{resource}", tag = "crud",
    params(("resource" = String, Path)),
    request_body = Value,
    responses((status = 200, description = "Created entity", body = Value),
              (status = 400, body = ErrorResponse), (status = 403, body = ErrorResponse))
)]
fn crud_create() {}

#[utoipa::path(
    get, path = "/api/{resource}/{id}", tag = "crud",
    params(("resource" = String, Path), ("id" = i64, Path)),
    responses((status = 200, body = Value), (status = 404, body = ErrorResponse))
)]
fn crud_get() {}

#[utoipa::path(
    put, path = "/api/{resource}/{id}", tag = "crud",
    params(("resource" = String, Path), ("id" = i64, Path)),
    request_body = Value,
    responses((status = 200, body = Value), (status = 400, body = ErrorResponse),
              (status = 404, body = ErrorResponse))
)]
fn crud_update() {}

#[utoipa::path(
    delete, path = "/api/{resource}/{id}", tag = "crud",
    params(("resource" = String, Path), ("id" = i64, Path)),
    responses((status = 200, body = Value), (status = 404, body = ErrorResponse))
)]
fn crud_delete() {}

macro_rules! analytics_path {
    ($fn:ident, $path:literal, $summary:literal $(, ($p:literal, $ty:ty, $desc:literal))*) => {
        #[utoipa::path(
            get, path = $path, tag = "analytics", summary = $summary,
            params($(($p = Option<$ty>, Query, description = $desc)),*),
            responses((status = 200, description = "Rows as JSON array", body = Vec<Value>))
        )]
        fn $fn() {}
    };
}

analytics_path!(a_q1, "/api/analytics/subscribers", "Q1. Subscribers of a PBX",
    ("pbx_id", i64, "PBX id"), ("category", String, "regular|privileged"),
    ("min_age", i32, "min age"), ("max_age", i32, "max age"), ("surname", String, "surname prefix"));
analytics_path!(a_q2, "/api/analytics/free-numbers", "Q2. Free numbers",
    ("pbx_id", i64, "PBX id"), ("district", String, "district"));
analytics_path!(a_q3, "/api/analytics/debtors", "Q3. Debtors",
    ("pbx_id", i64, "PBX id"), ("district", String, "district"),
    ("min_days", i32, "overdue days >="), ("kind", String, "any|subscription|intercity"),
    ("min_amount", f64, "total debt >="));
analytics_path!(a_q4, "/api/analytics/pbx-debt-ranking", "Q4. PBX ranking by debt",
    ("pbx_type", String, "city|departmental|institutional"));
analytics_path!(a_q5, "/api/analytics/public-phones", "Q5. Public phones / payphones",
    ("pbx_id", i64, "PBX id"), ("district", String, "district"), ("kind", String, "public|payphone"));
analytics_path!(a_q6, "/api/analytics/category-ratio", "Q6. Regular/privileged ratio",
    ("pbx_id", i64, "PBX id"), ("district", String, "district"), ("pbx_type", String, "PBX type"));
analytics_path!(a_q7, "/api/analytics/parallel-subscribers", "Q7. Subscribers with parallel phones",
    ("pbx_id", i64, "PBX id"), ("district", String, "district"),
    ("pbx_type", String, "PBX type"), ("privileged_only", bool, "privileged only"));
analytics_path!(a_q8, "/api/analytics/phones-by-address", "Q8. Phones by address",
    ("district", String, "district"), ("street", String, "street"), ("house", String, "house"));

#[utoipa::path(get, path = "/api/analytics/top-intercity-city", tag = "analytics",
    summary = "Q9. City with the most intercity calls",
    responses((status = 200, body = Vec<Value>)))]
fn a_q9() {}

analytics_path!(a_q10, "/api/analytics/subscriber-by-number", "Q10. Subscribers by number",
    ("number", String, "phone number"));
analytics_path!(a_q11, "/api/analytics/splittable-paired", "Q11. Splittable paired phones",
    ("pbx_id", i64, "PBX id"));
analytics_path!(a_q12, "/api/analytics/low-external-call-numbers", "Q12. Numbers with few external calls",
    ("pbx_id", i64, "PBX id"), ("from", String, "from (RFC3339/date)"),
    ("to", String, "to (RFC3339/date)"), ("max_calls", i64, "fewer than N"));
analytics_path!(a_q13, "/api/analytics/action-needed-debtors", "Q13. Debtors needing action",
    ("pbx_id", i64, "PBX id"), ("district", String, "district"));

#[utoipa::path(
    post, path = "/api/raw-query", tag = "raw-query",
    request_body = RawQueryInput,
    responses(
        (status = 200, description = "Rows as JSON array", body = Vec<Value>),
        (status = 400, description = "Only a single SELECT/WITH is allowed", body = ErrorResponse),
    )
)]
fn raw_query_run() {}

#[utoipa::path(get, path = "/api/admin/permissions", tag = "admin",
    responses((status = 200, body = Vec<Value>)))]
fn admin_list_permissions() {}

#[utoipa::path(get, path = "/api/admin/roles", tag = "admin",
    responses((status = 200, body = Vec<Value>)))]
fn admin_list_roles() {}

#[utoipa::path(post, path = "/api/admin/roles", tag = "admin",
    request_body = RoleInput, responses((status = 200, body = Value)))]
fn admin_create_role() {}

#[utoipa::path(put, path = "/api/admin/roles/{id}", tag = "admin",
    params(("id" = i64, Path)), request_body = RoleInput,
    responses((status = 200, body = Value), (status = 404, body = ErrorResponse)))]
fn admin_update_role() {}

#[utoipa::path(delete, path = "/api/admin/roles/{id}", tag = "admin",
    params(("id" = i64, Path)),
    responses((status = 200, body = Value), (status = 400, description = "System role", body = ErrorResponse)))]
fn admin_delete_role() {}

#[utoipa::path(post, path = "/api/admin/roles/{id}/permissions", tag = "admin",
    params(("id" = i64, Path)), request_body = PermissionIdsInput,
    responses((status = 200, body = Value)))]
fn admin_set_role_permissions() {}

#[utoipa::path(get, path = "/api/admin/users", tag = "admin",
    responses((status = 200, body = Vec<Value>)))]
fn admin_list_users() {}

#[utoipa::path(post, path = "/api/admin/users", tag = "admin",
    request_body = CreateUserInput, responses((status = 200, body = Value)))]
fn admin_create_user() {}

#[utoipa::path(put, path = "/api/admin/users/{id}", tag = "admin",
    params(("id" = i64, Path)), request_body = UpdateUserInput,
    responses((status = 200, body = Value), (status = 404, body = ErrorResponse)))]
fn admin_update_user() {}

#[utoipa::path(delete, path = "/api/admin/users/{id}", tag = "admin",
    params(("id" = i64, Path)),
    responses((status = 200, body = Value), (status = 400, body = ErrorResponse)))]
fn admin_delete_user() {}

#[utoipa::path(post, path = "/api/admin/users/{id}/roles", tag = "admin",
    params(("id" = i64, Path)), request_body = RoleIdsInput,
    responses((status = 200, body = Value)))]
fn admin_set_user_roles() {}

#[utoipa::path(post, path = "/api/portal/register", tag = "portal",
    request_body = CustomerRegister, responses((status = 200, body = Value)))]
fn portal_register() {}

#[utoipa::path(post, path = "/api/portal/login", tag = "portal",
    request_body = CustomerLogin, responses((status = 200, body = Value), (status = 401, body = ErrorResponse)))]
fn portal_login() {}

#[utoipa::path(post, path = "/api/portal/logout", tag = "portal", responses((status = 200, body = StatusResponse)))]
fn portal_logout() {}

#[utoipa::path(get, path = "/api/portal/me", tag = "portal", responses((status = 200, body = Value)))]
fn portal_me() {}

#[utoipa::path(get, path = "/api/portal/overview", tag = "portal",
    summary = "Линии, абонплата, долг, заявки", responses((status = 200, body = Value)))]
fn portal_overview() {}

#[utoipa::path(get, path = "/api/portal/applications", tag = "portal", responses((status = 200, body = Vec<Value>)))]
fn portal_list_applications() {}

#[utoipa::path(post, path = "/api/portal/applications", tag = "portal",
    summary = "Подать заявку на подключение", request_body = ApplyInput, responses((status = 200, body = Value)))]
fn portal_apply() {}

#[utoipa::path(put, path = "/api/portal/lines/{number_id}/intercity", tag = "portal",
    summary = "Включить/выключить межгород",
    params(("number_id" = i64, Path)), request_body = IntercityInput, responses((status = 200, body = Value)))]
fn portal_set_intercity() {}

#[utoipa::path(post, path = "/api/portal/lines/{number_id}/call", tag = "portal",
    summary = "Совершить (симулировать) звонок",
    params(("number_id" = i64, Path)), request_body = CallInput, responses((status = 200, body = Value)))]
fn portal_call() {}

#[utoipa::path(get, path = "/api/portal/lines/{number_id}/calls", tag = "portal",
    params(("number_id" = i64, Path)), responses((status = 200, body = Vec<Value>)))]
fn portal_calls() {}

#[utoipa::path(get, path = "/api/portal/invoices", tag = "portal", responses((status = 200, body = Vec<Value>)))]
fn portal_invoices() {}

#[utoipa::path(post, path = "/api/portal/invoices/{id}/pay", tag = "portal",
    params(("id" = i64, Path)), responses((status = 200, body = Value)))]
fn portal_pay() {}

#[utoipa::path(get, path = "/api/ops/applications", tag = "ops",
    summary = "Заявки на подключение (для оператора)", responses((status = 200, body = Vec<Value>)))]
fn ops_applications() {}

#[utoipa::path(post, path = "/api/ops/applications/{id}/provision", tag = "ops",
    summary = "Подключить заявку: выдать номер, создать абонента",
    params(("id" = i64, Path)), request_body = ProvisionInput, responses((status = 200, body = Value)))]
fn ops_provision() {}

struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.as_mut().unwrap();
        components.add_security_scheme(
            "session_cookie",
            SecurityScheme::ApiKey(ApiKey::Cookie(ApiKeyValue::new("id"))),
        );
    }
}

#[derive(OpenApi)]
#[openapi(
    info(
        title = "Информационная система ГТС — API",
        version = "0.1.0",
        description = "REST API городской телефонной сети: аутентификация, RBAC, CRUD по всем сущностям, 13 аналитических запросов варианта и выполнение сырых SELECT-запросов."
    ),
    paths(
        auth_login, auth_logout, auth_me,
        crud_list, crud_create, crud_get, crud_update, crud_delete,
        a_q1, a_q2, a_q3, a_q4, a_q5, a_q6, a_q7, a_q8, a_q9, a_q10, a_q11, a_q12, a_q13,
        raw_query_run,
        admin_list_permissions,
        admin_list_roles, admin_create_role, admin_update_role, admin_delete_role, admin_set_role_permissions,
        admin_list_users, admin_create_user, admin_update_user, admin_delete_user, admin_set_user_roles,
        portal_register, portal_login, portal_logout, portal_me, portal_overview,
        portal_list_applications, portal_apply, portal_set_intercity, portal_call, portal_calls,
        portal_invoices, portal_pay,
        ops_applications, ops_provision,
    ),
    components(schemas(
        LoginRequest, UserResponse, ErrorResponse, StatusResponse, CrudPage,
        RoleInput, PermissionIdsInput, RoleIdsInput, CreateUserInput, UpdateUserInput, RawQueryInput,
        CustomerRegister, CustomerLogin, ApplyInput, IntercityInput, CallInput, ProvisionInput,
    )),
    modifiers(&SecurityAddon),
    security(("session_cookie" = [])),
    tags(
        (name = "auth", description = "Аутентификация и сессия"),
        (name = "crud", description = "CRUD по всем сущностям (общий контракт)"),
        (name = "analytics", description = "13 аналитических запросов варианта"),
        (name = "raw-query", description = "Выполнение сырых SELECT-запросов"),
        (name = "admin", description = "Управление пользователями, ролями и правами (RBAC)"),
        (name = "portal", description = "Личный кабинет абонента (самообслуживание)"),
        (name = "ops", description = "Операторские действия (подключение заявок)"),
    )
)]
pub struct ApiDoc;
