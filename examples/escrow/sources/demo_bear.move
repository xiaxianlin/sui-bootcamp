module escrow::demo_bear;

use std::string::{String, utf8};
use sui::display;
use sui::package;

public struct DemoBear has key, store {
    id: UID,
    name: String,
}

public struct DEMO_BEAR has drop {}

fun init(otw: DEMO_BEAR, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    let keys = vector[utf8(b"name"), utf8(b"image_url"), utf8(b"description")];

    let values = vector[
        utf8(b"{name}"),
        utf8(
            b"https://images.unsplash.com/photo-1589656966895-2f33e7653819?q=80&w=1000&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8cG9sYXIlMjBiZWFyfGVufDB8fDB8fHww",
        ),
        utf8(b"The greatest figure for demos"),
    ];

    let mut display = display::new_with_fields<DemoBear>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display::update_version(&mut display);

    sui::transfer::public_transfer(display, ctx.sender());
    sui::transfer::public_transfer(publisher, ctx.sender())
}

public fun new(name: String, ctx: &mut TxContext): DemoBear {
    DemoBear {
        id: object::new(ctx),
        name: name,
    }
}
