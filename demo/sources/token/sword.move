module demo::sword;

use demo::gem::GEM;
use sui::token::{Self, Token, ActionRequest};

const EWrongAmount: u64 = 0;
const SWORD_PRICE: u64 = 10;

public struct Sword has key, store { id: UID }

public fun buy_sword(gems: Token<GEM>, ctx: &mut TxContext): (Sword, ActionRequest<GEM>) {
    assert!(SWORD_PRICE == token::value(&gems), EWrongAmount);
    (Sword { id: object::new(ctx) }, token::spend(gems, ctx))
}
