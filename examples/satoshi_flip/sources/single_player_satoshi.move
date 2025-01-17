module satoshi_flip::single_player_satoshi;

use satoshi_flip::counter_nft::Counter;
use satoshi_flip::house_data::HouseData;
use std::string::String;
use sui::balance::Balance;
use sui::bls12381::bls12381_min_pk_verify;
use sui::coin::{Self, Coin};
use sui::dynamic_object_field as dof;
use sui::event::emit;
use sui::hash::blake2b256;
use sui::sui::SUI;

const EPOCHS_CANCEL_AFTER: u64 = 7;
const GAME_RETURN: u8 = 2;
const PLAYER_WON_STATE: u8 = 1;
const HOUSE_WON_STATE: u8 = 2;
const CHALLENGED_STATE: u8 = 3;
const HEADS: vector<u8> = b"H";
const TAILS: vector<u8> = b"T";

const EStakeTooLow: u64 = 0;
const EStakeTooHigh: u64 = 1;
const EInvalidBlsSig: u64 = 2;
const ECanNotChallengeYet: u64 = 3;
const EInvalidGuess: u64 = 4;
const EInsufficientHouseBalance: u64 = 5;
const EGameDoesNotExist: u64 = 6;

/// 游戏
public struct Game has key, store {
    id: UID,
    /// 下注的纪元
    guess_placed_epoch: u64,
    /// 投注额度
    total_stake: Balance<SUI>,
    guess: String,
    /// 发起游戏的玩家
    player: address,
    vrf_input: vector<u8>,
    /// 庄家的抽成
    fee_bp: u16,
}

/// 开始游戏
public fun start_game(
    guess: String,
    counter: &mut Counter,
    coin: Coin<SUI>,
    house_data: &mut HouseData,
    ctx: &mut TxContext,
): ID {
    // 获取庄家的抽成
    let fee_bp = house_data.base_fee_in_bp();
    // 生成游戏
    let (id, new_game) = internal_start_game(guess, counter, coin, house_data, fee_bp, ctx);
    // 将游戏添加到庄家
    dof::add(house_data.borrow_mut(), id, new_game);
    id
}

/// 结束游戏
public fun finish_game(
    game_id: ID,
    bls_sig: vector<u8>,
    house_data: &mut HouseData,
    ctx: &mut TxContext,
) {
    assert!(game_exists(house_data, game_id), EGameDoesNotExist);
    // 销毁游戏
    let Game {
        id,
        guess_placed_epoch: _,
        mut total_stake,
        guess,
        player,
        vrf_input,
        fee_bp,
    } = dof::remove<ID, Game>(house_data.borrow_mut(), game_id);
    id.delete();

    // 校验密钥是否正确
    let is_sig_valid = bls12381_min_pk_verify(&bls_sig, &house_data.public_key(), &vrf_input);
    assert!(is_sig_valid, EInvalidBlsSig);

    let hashed_beacon = blake2b256(&bls_sig);
    let first_byte = hashed_beacon[0];
    let player_won = map_guess(guess) == (first_byte % 2);

    let status = if (player_won) {
        let stake_amount = total_stake.value();
        let fee_amount = fee_amount(stake_amount, fee_bp);
        let fees = total_stake.split(fee_amount);
        house_data.borrow_fees_mut().join(fees);

        transfer::public_transfer(total_stake.into_coin(ctx), player);
        PLAYER_WON_STATE
    } else {
        house_data.borrow_balance_mut().join(total_stake);
        HOUSE_WON_STATE
    };

    emit(Outcome {
        game_id,
        status,
    });
}

public fun dispute_and_win(house_data: &mut HouseData, game_id: ID, ctx: &mut TxContext) {
    assert!(game_exists(house_data, game_id), EGameDoesNotExist);

    let Game {
        id,
        guess_placed_epoch,
        total_stake,
        guess: _,
        player,
        vrf_input: _,
        fee_bp: _,
    } = dof::remove(house_data.borrow_mut(), game_id);
    id.delete();

    let caller_epoch = ctx.epoch();
    let cancel_epoch = guess_placed_epoch + EPOCHS_CANCEL_AFTER;

    assert!(cancel_epoch <= caller_epoch, ECanNotChallengeYet);

    transfer::public_transfer(total_stake.into_coin(ctx), player);

    emit(Outcome {
        game_id,
        status: CHALLENGED_STATE,
    });
}

// --------------- Read-only References ---------------

public fun guess_placed_epoch(game: &Game): u64 {
    game.guess_placed_epoch
}

public fun stake(game: &Game): u64 {
    game.total_stake.value()
}

public fun guess(game: &Game): u8 {
    map_guess(game.guess)
}

public fun player(game: &Game): address {
    game.player
}

public fun vrf_input(game: &Game): vector<u8> {
    game.vrf_input
}

public fun fee_in_bp(game: &Game): u16 {
    game.fee_bp
}

// --------------- Helper functions ---------------

public fun fee_amount(game_stake: u64, fee_in_bp: u16): u64 {
    ((((game_stake / (GAME_RETURN  as u64)) as u128) * (fee_in_bp as u128) / 10_000) as u64)
}

public fun game_exists(house_data: &HouseData, game_id: ID): bool {
    dof::exists_(house_data.borrow(), game_id)
}

public fun borrow_game(game_id: ID, house_data: &HouseData): &Game {
    assert!(game_exists(house_data, game_id), EGameDoesNotExist);
    dof::borrow(house_data.borrow(), game_id)
}

/// 开始游戏
fun internal_start_game(
    guess: String,
    counter: &mut Counter,
    coin: Coin<SUI>,
    house_data: &mut HouseData,
    fee_bp: u16,
    ctx: &mut TxContext,
): (ID, Game) {
    map_guess(guess);
    // 玩家的押注
    let player_stake = coin.value();
    // 玩家押注过大
    assert!(player_stake <= house_data.max_stake(), EStakeTooHigh);
    // 玩家押注过小
    assert!(player_stake >= house_data.min_stake(), EStakeTooLow);
    // 庄家余额不足
    assert!(house_data.balance() >= player_stake, EInsufficientHouseBalance);

    // 从庄家的余额里拿出押注额度到当前游戏
    let mut total_stake = house_data.borrow_balance_mut().split(player_stake);
    coin::put(&mut total_stake, coin);

    // 从计数器里面获取 VRF 输入
    let vrf_input = counter.get_vrf_input_and_increment();

    let id = object::new(ctx);
    let game_id = object::uid_to_inner(&id);

    let new_game = Game {
        id,
        guess_placed_epoch: ctx.epoch(),
        total_stake,
        guess,
        player: ctx.sender(),
        vrf_input,
        fee_bp,
    };
    emit(NewGame {
        game_id,
        player: ctx.sender(),
        vrf_input,
        guess,
        player_stake,
        fee_bp,
    });

    (game_id, new_game)
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

public struct NewGame has copy, drop {
    game_id: ID,
    player: address,
    vrf_input: vector<u8>,
    guess: String,
    player_stake: u64,
    fee_bp: u16,
}

public struct Outcome has copy, drop {
    game_id: ID,
    status: u8,
}
