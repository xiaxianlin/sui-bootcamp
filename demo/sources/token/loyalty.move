module demo::loyalty;

use sui::coin::{Self, TreasuryCap};
use sui::token::{Self, Token, ActionRequest};

const EIncorrectAmount: u64 = 0;
const GIFT_PRICE: u64 = 10;

public struct LOYALTY has drop {}

public struct Gift has key, store {
    id: UID,
}

public struct GiftShop has drop {}

fun init(otw: LOYALTY, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = coin::create_currency(
        otw,
        0,
        b"LOY",
        b"Loyalty Token",
        b"Token for Loyalty",
        option::none(),
        ctx,
    );

    let (mut policy, policy_cap) = token::new_policy(&treasury_cap, ctx);

    token::add_rule_for_action<LOYALTY, GiftShop>(
        &mut policy,
        &policy_cap,
        token::spend_action(),
        ctx,
    );

    token::share_policy(policy);

    transfer::public_freeze_object(coin_metadata);
    transfer::public_transfer(policy_cap, ctx.sender());
    transfer::public_transfer(treasury_cap, ctx.sender());
}

public fun reward_user(
    cap: &mut TreasuryCap<LOYALTY>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let token = token::mint(cap, amount, ctx);
    let req = token::transfer(token, recipient, ctx);

    token::confirm_with_treasury_cap(cap, req, ctx);
}

public fun buy_a_gift(token: Token<LOYALTY>, ctx: &mut TxContext): (Gift, ActionRequest<LOYALTY>) {
    assert!(token::value(&token) == GIFT_PRICE, EIncorrectAmount);

    let gift = Gift { id: object::new(ctx) };
    let mut req = token::spend(token, ctx);

    token::add_approval(GiftShop {}, &mut req, ctx);
    (gift, req)
}
