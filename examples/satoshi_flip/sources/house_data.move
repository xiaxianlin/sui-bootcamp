module satoshi_flip::house_data;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::package;
use sui::sui::SUI;

const EcallerNotHouse: u64 = 0;
const EInsufficientBalance: u64 = 1;

/// 庄家数据
public struct HouseData has key {
    id: UID,
    /// 庄家余额
    balance: Balance<SUI>,
    /// 庄家账户
    house: address,
    /// 校验密钥，由后端生成
    public_key: vector<u8>,
    /// 最大押注
    max_stake: u64,
    /// 最小押注
    min_stake: u64,
    fees: Balance<SUI>,
    /// 庄家抽点
    base_fee_in_bp: u16,
}

public struct HouseCap has key {
    id: UID,
}

/// 一次性见证者，确保庄家数据仅存在一个实例
public struct HOUSE_DATA has drop {}

/// 初始化庄家数据的管理权限
fun init(otw: HOUSE_DATA, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);

    let house_cap = HouseCap { id: object::new(ctx) };

    transfer::transfer(house_cap, ctx.sender());
}

/// 初始化庄家数据
public fun initialize_house_data(
    house_cap: HouseCap, // 权限
    coin: Coin<SUI>, // 初始金额
    public_key: vector<u8>, //
    ctx: &mut TxContext,
) {
    assert!(coin.value() > 0, EInsufficientBalance);

    let house_data = HouseData {
        id: object::new(ctx),
        balance: coin.into_balance(),
        house: ctx.sender(),
        public_key,
        max_stake: 50_000_000_000, // 50 SUI
        min_stake: 1_000_000_000, // 1 SUI
        fees: balance::zero(),
        base_fee_in_bp: 100,
    };

    // 庄家数据初始化后销毁权限
    let HouseCap { id } = house_cap;
    id.delete();

    transfer::share_object(house_data);
}

/// 添加头寸
public fun top_up(house_data: &mut HouseData, coin: Coin<SUI>, _: &mut TxContext) {
    coin::put(&mut house_data.balance, coin);
}

/// 庄家提取余额
public fun withdraw(house_data: &mut HouseData, ctx: &mut TxContext) {
    assert!(ctx.sender() == house_data.house(), EcallerNotHouse);

    let total_balance = balance(house_data);
    let coin = coin::take(&mut house_data.balance, total_balance, ctx);
    transfer::public_transfer(coin, house_data.house());
}

/// 庄家提取手续费
public fun claim_fees(house_data: &mut HouseData, ctx: &mut TxContext) {
    assert!(ctx.sender() == house_data.house(), EcallerNotHouse);

    let total_fees = fees(house_data);
    let coin = coin::take(&mut house_data.fees, total_fees, ctx);
    transfer::public_transfer(coin, house_data.house());
}

/// 修改最大押注
public fun update_max_stake(house_data: &mut HouseData, max_stake: u64, ctx: &mut TxContext) {
    assert!(ctx.sender() == house_data.house(), EcallerNotHouse);

    house_data.max_stake = max_stake;
}

/// 修改最小押注
public fun update_min_stake(house_data: &mut HouseData, min_stake: u64, ctx: &mut TxContext) {
    assert!(ctx.sender() == house_data.house(), EcallerNotHouse);

    house_data.min_stake = min_stake;
}

// --------------- Mutable References ---------------

public(package) fun borrow_balance_mut(house_data: &mut HouseData): &mut Balance<SUI> {
    &mut house_data.balance
}

public(package) fun borrow_fees_mut(house_data: &mut HouseData): &mut Balance<SUI> {
    &mut house_data.fees
}

public(package) fun borrow_mut(house_data: &mut HouseData): &mut UID {
    &mut house_data.id
}

// --------------- Read-only References ---------------

public(package) fun borrow(house_data: &HouseData): &UID {
    &house_data.id
}

public fun balance(house_data: &mut HouseData): u64 {
    house_data.balance.value()
}

public fun house(house_data: &mut HouseData): address {
    house_data.house
}

public fun public_key(house_data: &mut HouseData): vector<u8> {
    house_data.public_key
}

public fun max_stake(house_data: &mut HouseData): u64 {
    house_data.max_stake
}

public fun min_stake(house_data: &mut HouseData): u64 {
    house_data.min_stake
}

public fun fees(house_data: &mut HouseData): u64 {
    house_data.fees.value()
}

public fun base_fee_in_bp(house_data: &mut HouseData): u16 {
    house_data.base_fee_in_bp
}

// --------------- Test-only Functions ---------------

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(HOUSE_DATA {}, ctx);
}
