module satoshi_flip::game;

use satoshi_flip::ticket::Ticket;
use std::string::String;
use sui::balance::Balance;
use sui::bls12381::bls12381_min_pk_verify;
use sui::coin::Coin;
use sui::event::emit;
use sui::hash::blake2b256;
use sui::sui::SUI;

const HEADS: vector<u8> = b"H";
const TAILS: vector<u8> = b"T";

const EInvalidGuess: u64 = 0;
const EInsufficientHouseBalance: u64 = 1;
const ETicketNotMatch: u64 = 2;
const EInvalidBlsSig: u64 = 3;
const EGameIsBegin: u64 = 4;
const ECallerNotHouse: u64 = 5;
const EInsufficientBalance: u64 = 6;

public struct Game has key {
    id: UID,
    balance: Balance<SUI>,
    public_key: vector<u8>,
    owner: address,
    status: u8,
}

public fun create(public_key: vector<u8>, coin: Coin<SUI>, ctx: &mut TxContext) {
    let amount = coin.value();
    assert!(amount > 0, EInsufficientBalance);

    let id = object::new(ctx);
    let game_id = object::uid_to_inner(&id);
    let game = Game {
        id,
        balance: coin.into_balance(),
        owner: ctx.sender(),
        public_key,
        status: 0,
    };

    transfer::transfer(game, ctx.sender());
    emit(CreateGame {
        game_id,
        owner: ctx.sender(),
        balence: amount,
    });
}

public fun play(
    ticket: &mut Ticket,
    game: &mut Game,
    guess: String,
    bls_sig: vector<u8>,
    ctx: &mut TxContext,
) {
    assert!(ticket.owner() == ctx.sender(), ETicketNotMatch);
    assert!(ticket.balance() >= game.balance(), EInsufficientHouseBalance);
    assert!(game.status == 0, EGameIsBegin);
    map_guess(guess);

    let vrf_input = ticket.get_vrf_input();
    let is_sig_valid = bls12381_min_pk_verify(&bls_sig, &game.public_key, &vrf_input);
    assert!(is_sig_valid, EInvalidBlsSig);

    game.status = 1;

    let hashed_beacon = blake2b256(&bls_sig);
    let player_won = map_guess(guess) == (hashed_beacon[0] % 2);
    let amount = game.balance();
    if (player_won) {
        let balance = game.balance.split(amount);
        ticket.borrow_balance_mut().join(balance);
    } else {
        let balance = ticket.borrow_balance_mut().split(amount);
        game.balance.join(balance);
    };
}

#[allow(lint(self_transfer))]
public fun withdraw(game: Game, ctx: &mut TxContext) {
    assert!(ctx.sender() == game.owner, ECallerNotHouse);
    let Game { id, balance, public_key: _, owner: _, status: _ } = game;
    emit(Withdraw {
        game_id: object::uid_to_inner(&id),
        owner: ctx.sender(),
        balence: balance.value(),
    });

    id.delete();
    transfer::public_transfer(balance.into_coin(ctx), ctx.sender());
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

public fun balance(self: &Game): u64 {
    self.balance.value()
}

// --------------- EVENTS ---------------

public struct CreateGame has copy, drop {
    game_id: ID,
    owner: address,
    balence: u64,
}

public struct Withdraw has copy, drop {
    game_id: ID,
    owner: address,
    balence: u64,
}
