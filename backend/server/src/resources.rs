//! Wires every SeaORM entity into the generic CRUD layer with its permission name.

use axum::Router;

use crate::{crud::crud_routes, crud::Resource, state::AppState};

macro_rules! resource {
    ($module:ident, $name:expr) => {
        impl Resource for entity::$module::Entity {
            const NAME: &'static str = $name;
        }
    };
}

resource!(pbx, "pbx");
resource!(pbx_city, "pbx_city");
resource!(pbx_department, "pbx_department");
resource!(pbx_institution, "pbx_institution");
resource!(subscriber, "subscriber");
resource!(phone_number, "phone_number");
resource!(address, "address");
resource!(city, "city");
resource!(call_record, "call");
resource!(tariff, "tariff");
resource!(invoice, "invoice");
resource!(payment, "payment");
resource!(penalty, "penalty");
resource!(notification, "notification");
resource!(installation_queue, "queue");
resource!(public_phone, "public_phone");

/// Mount all CRUD resources under their REST paths.
pub fn api_router() -> Router<AppState> {
    Router::new()
        .nest("/pbx", crud_routes::<entity::pbx::Entity>())
        .nest("/pbx-city", crud_routes::<entity::pbx_city::Entity>())
        .nest("/pbx-department", crud_routes::<entity::pbx_department::Entity>())
        .nest("/pbx-institution", crud_routes::<entity::pbx_institution::Entity>())
        .nest("/subscribers", crud_routes::<entity::subscriber::Entity>())
        .nest("/phone-numbers", crud_routes::<entity::phone_number::Entity>())
        .nest("/addresses", crud_routes::<entity::address::Entity>())
        .nest("/cities", crud_routes::<entity::city::Entity>())
        .nest("/calls", crud_routes::<entity::call_record::Entity>())
        .nest("/tariffs", crud_routes::<entity::tariff::Entity>())
        .nest("/invoices", crud_routes::<entity::invoice::Entity>())
        .nest("/payments", crud_routes::<entity::payment::Entity>())
        .nest("/penalties", crud_routes::<entity::penalty::Entity>())
        .nest("/notifications", crud_routes::<entity::notification::Entity>())
        .nest("/queue", crud_routes::<entity::installation_queue::Entity>())
        .nest("/public-phones", crud_routes::<entity::public_phone::Entity>())
}
