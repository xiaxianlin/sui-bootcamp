module demo::gem;

use std::option::none;
use std::string::{Self, String};
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin, TreasuryCap};
use sui::sui::SUI;
use sui::token::{Self, Token, ActionRequest};
use sui::tx_context::sender;

const EUnknownAmount: u64 = 0;

const SMALL_BUNDLE: u64 = 10_000_000_000;
const SMALL_AMOUNT: u64 = 100;

const MEDIUM_BUNDLE: u64 = 100_000_000_000;
const MEDIUM_AMOUNT: u64 = 5_000;

const LARGE_BUNDLE: u64 = 1_000_000_000_000;
const LARGE_AMOUNT: u64 = 100_000;

public struct GEM has drop {}

#[allow(lint(coin_field))]
public struct GemStore has key {
    id: UID,
    profits: Balance<SUI>,
    gem_treasury: TreasuryCap<GEM>,
}

fun init(otw: GEM, ctx: &mut TxContext) {
    let (treasury_cap, coin_metadata) = coin::create_currency(
        otw,
        0,
        b"GEM",
        b"Capy Gems",
        b"In-game currency for Capy Miners",
        none(),
        ctx,
    );

    let (mut policy, cap) = token::new_policy(&treasury_cap, ctx);
    token::allow(&mut policy, &cap, buy_action(), ctx);
    token::allow(&mut policy, &cap, token::spend_action(), ctx);

    transfer::share_object(GemStore {
        id: object::new(ctx),
        gem_treasury: treasury_cap,
        profits: balance::zero(),
    });

    transfer::public_freeze_object(coin_metadata);
    transfer::public_transfer(cap, ctx.sender());
    token::share_policy(policy);
}

public fun buey_gems(
    self: &mut GemStore,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
): (Token<GEM>, ActionRequest<GEM>) {
    let amount = coin::value(&payment);
    let purchased = if (amount == SMALL_BUNDLE) {
        SMALL_BUNDLE
    } else if (amount == MEDIUM_BUNDLE) {
        MEDIUM_BUNDLE
    } else if (amount == LARGE_BUNDLE) {
        LARGE_BUNDLE
    } else {
        abort EUnknownAmount
    };

    coin::put(&mut self.profits, payment);
    let gems = token::mint(&mut self.gem_treasury, purchased, ctx);
    let req = token::new_request(buy_action(), purchased, none(), none(), ctx);
    (gems, req)
}

public fun buy_action(): String {
    string::utf8(b"Buy")
}
