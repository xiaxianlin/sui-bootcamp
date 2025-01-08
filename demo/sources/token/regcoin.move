module demo::regcoin;

use sui::coin::{Self, DenyCapV2};
use sui::deny_list::DenyList;

public struct REGCOIN has drop {}

fun init(witness: REGCOIN, ctx: &mut TxContext) {
    let (treasury, deny_cap, metadata) = coin::create_regulated_currency_v2(
        witness,
        6,
        b"REGCOIN",
        b"",
        b"",
        option::none(),
        false,
        ctx,
    );

    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
    transfer::public_transfer(deny_cap, ctx.sender());
}

public fun add_addr_from_deny_list(
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV2<REGCOIN>,
    deny_addr: address,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_add(deny_list, deny_cap, deny_addr, ctx);
}

public fun remove_addr_from_deny_list(
    deny_list: &mut DenyList,
    deny_cap: &mut DenyCapV2<REGCOIN>,
    deny_addr: address,
    ctx: &mut TxContext,
) {
    coin::deny_list_v2_remove(deny_list, deny_cap, deny_addr, ctx);
}
