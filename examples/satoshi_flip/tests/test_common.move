#[test_only]
module satoshi_flip::test_common;

use satoshi_flip::game;
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::Scenario;

// prettier-ignore
const PK: vector<u8> = vector<u8> [
    134, 225,   1, 158, 217, 213,  32,  70, 180,
    42, 251, 131,  44, 112, 114, 117, 186,  65,
    90, 223, 233, 110,  24, 254, 105, 205, 219,
    236,  49, 113,  59, 167, 137,  19, 119,  39,
    75, 146, 197, 214,  70, 164, 176, 221,  55,
    218,  63, 198
];

// prettier-ignore
const BLS_SIG: vector<u8> = vector<u8> [
    136, 154,   7, 173,  12,  37,  13,  33, 154,  16, 189, 218,
    133,  39, 103,  67, 231, 161, 180, 182,  59, 227, 242, 213,
    91, 110,  13, 152, 200,   6,  24, 209,  49, 121, 110, 130,
    243, 251, 142, 221,  90,  45, 109,   2, 109,  44, 180, 110,
    22,  22,   0,  72,  86, 201, 109, 197,  43, 253, 177,  74,
    98, 233, 112, 120, 171, 188, 107,  94,  21,   9,  66, 248,
    190, 130, 117, 137, 118, 234, 205,  44,   1, 109, 251, 198,
    162, 219, 188,  29, 128, 225,  75, 193, 205,   0, 180, 145
];

const INITIAL_HOUSE_BALANCE: u64 = 5_000_000_000; // 1 SUI
const INITIAL_PLAYER_BALANCE: u64 = 3_000_000_000; // 3 SUI

public fun get_initial_house_balance(): u64 {
    INITIAL_HOUSE_BALANCE
}

public fun get_initial_player_balance(): u64 {
    INITIAL_PLAYER_BALANCE
}

public fun fund_addresses(
    scenario: &mut Scenario,
    house: address,
    player: address,
    house_funds: u64,
    player_funds: u64,
) {
    let ctx = scenario.ctx();
    let coinA = coin::mint_for_testing<SUI>(house_funds, ctx);
    let coinB = coin::mint_for_testing<SUI>(player_funds, ctx);
    transfer::public_transfer(coinA, house);
    transfer::public_transfer(coinB, player);
}

public fun init_game(scenario: &mut Scenario, house: address) {
    scenario.next_tx(house);
    {
        let coin = scenario.take_from_sender<Coin<SUI>>();
        game::create(PK, coin, scenario.ctx());
    };
}



public fun play_game(scenario: &mut Scenario, house: address) {
    scenario.next_tx(house);
    {
        let coin = scenario.take_from_sender<Coin<SUI>>();
        game::create(PK, coin, scenario.ctx());
    };
}
