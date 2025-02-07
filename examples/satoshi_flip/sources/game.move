module satoshi_flip::game;

use satoshi_flip::ticket::Ticket;
use std::string::String;
use sui::balance::Balance;
use sui::bls12381::bls12381_min_pk_verify;
use sui::coin::{Self, Coin};
use sui::event::emit;
use sui::hash::blake2b256;
use sui::sui::SUI;

const PLAYER_WON_STATE: u8 = 1;
const HOUSE_WON_STATE: u8 = 2;
const HEADS: vector<u8> = b"H";
const TAILS: vector<u8> = b"T";

const EInvalidGuess: u64 = 0;
const EInsufficientHouseBalance: u64 = 1;
const ETicketNotMatch: u64 = 2;
const EInvalidBlsSig: u64 = 3;
const EGameIsBegin: u64 = 4;
const ECallerNotHouse: u64 = 5;
const EInsufficientBalance: u64 = 6;

public struct Game has key, store {
    id: UID,
    balance: Balance<SUI>,
    public_key: vector<u8>,
    house: address,
    status: u8,
}

#[allow(lint(self_transfer))]
public fun create(public_key: vector<u8>, coin: Coin<SUI>, ctx: &mut TxContext) {
    assert!(coin.value() > 0, EInsufficientBalance);
    let id = object::new(ctx);
    let game_id = object::uid_to_inner(&id);
    let game = Game {
        id,
        balance: coin.into_balance(),
        house: ctx.sender(),
        public_key,
        status: 0,
    };

    emit(CreateGame {
        game_id,
        house: ctx.sender(),
        balence: coin.into_balance().value(),
    });

    transfer::public_transfer(game, ctx.sender());
}

public fun stake(
    ticket: &mut Ticket,
    game: &mut Game,
    coin: Coin<SUI>,
    guess: String,
    bls_sig: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(ticket.owner() == ctx.sender(), ETicketNotMatch);

    let stake = coin.into_balance();
    assert!(game.balance.value() >= stake.value(), EInsufficientHouseBalance);
    assert!(game.status == 0, EGameIsBegin);
    map_guess(guess);

    game.status = 1;

    let vrf_input = ticket.get_vrf_input();

    let is_sig_valid = bls12381_min_pk_verify(&bls_sig, &game.public_key, &vrf_input);
    assert!(is_sig_valid, EInvalidBlsSig);

    let player = ctx.sender();
    let hashed_beacon = blake2b256(&bls_sig);
    let player_won = map_guess(guess) == (hashed_beacon[0] % 2);

    let status = if (player_won) {
        transfer::public_transfer(stake.into_coin(ctx), player);
        PLAYER_WON_STATE
    } else {
        game.balance.join(stake);
        HOUSE_WON_STATE
    };
}

public fun withdraw(game: &mut Game, ctx: &mut TxContext) {
    assert!(ctx.sender() == game.house, ECallerNotHouse);
    let total_balance = balance(game);
    let coin = coin::take(&mut game.balance, total_balance, ctx);
    transfer::public_transfer(coin, game.house());
}

fun map_guess(guess: String): u8 {
    let heads = HEADS;
    let tails = TAILS;
    assert!(guess.as_bytes() == heads || guess.as_bytes() == tails, EInvalidGuess);

    if (guess.as_bytes() == heads) {
        0
    } else {
        1
    }
}

// --------------- EVENTS ---------------

public struct CreateGame has copy, drop {
    game_id: ID,
    house: address,
    balence: u64,
}
