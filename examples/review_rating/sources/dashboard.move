module review_rating::dashboard;

use std::string::String;
use sui::dynamic_field as df;

public struct Dashboard has key, store {
    id: UID,
    service_type: String,
}

public fun create_dashboard(service_type: String, ctx: &mut TxContext) {
    let db = Dashboard { id: object::new(ctx), service_type };
    transfer::share_object(db);
}

public fun register_service(db: &mut Dashboard, service_id: ID) {
    df::add(&mut db.id, service_id, service_id);
}
