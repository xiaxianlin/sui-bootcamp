module demo::nft_rental;

use kiosk::kiosk_lock_rule::Rule as LockRule;
use sui::bag;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::kiosk::{Kiosk, KioskOwnerCap};
use sui::kiosk_extension;
use sui::package::Publisher;
use sui::sui::SUI;
use sui::transfer_policy::{Self, TransferPolicy, TransferPolicyCap, has_rule};

const EExtensionNotInstalled: u64 = 0;
const ENotOwner: u64 = 1;
const ENotEnoughCoins: u64 = 2;
const EInvalidKiosk: u64 = 3;
const ERentingPeriodNotOver: u64 = 4;
const EObjectNotExist: u64 = 5;
const ETotalPriceOverflow: u64 = 6;

const PERMISSIONS: u128 = 11;
const SECONDS_IN_A_DAY: u64 = 86400;
const MAX_BASIS_POINTS: u16 = 10_000;
const MAX_VALUE_U64: u64 = 0xff_ff_ff_ff__ff_ff_ff_ff;

/// 扩展密钥
public struct Rentables has drop {}

/// 租借物品，动态字段
public struct Rented has copy, drop, store {
    id: ID,
}

/// 租借清单，动态字段
public struct Listed has copy, drop, store {
    id: ID,
}

/// 按值借用
public struct Promise {
    /// 租赁物品
    item: Rented,
    /// 租赁周期
    duration: u64,
    /// 开始时间
    start_date: u64,
    /// 每日价格
    price_per_day: u64,
    renter_kiosk: ID,
    borrower_kiosk: ID,
}

/// 租赁信息
public struct Rentable<T: key + store> has store {
    /// 被租赁的资产
    object: T,
    /// 租赁期限
    duration: u64,
    /// 开始时间
    start_date: Option<u64>,
    /// 每日价格
    price_per_day: u64,
    /// 自助服务机的 ID
    kiosk_id: ID,
}

/// 出租策略
public struct RentalPolicy<phantom T> has key, store {
    id: UID,
    balance: Balance<SUI>,
    amount_bp: u64,
}

/// 受保护的传输策略
public struct ProtectedTP<phantom T> has key, store {
    id: UID,
    transfer_policy: TransferPolicy<T>,
    policy_cap: TransferPolicyCap<T>,
}

/// 安装 kiosk 插件
public fun install(kiosk: &mut Kiosk, cap: &KioskOwnerCap, ctx: &mut TxContext) {
    kiosk_extension::add(Rentables {}, kiosk, cap, PERMISSIONS, ctx);
}

/// 卸载插件
public fun remove(kiosk: &mut Kiosk, cap: &KioskOwnerCap, _: &mut TxContext) {
    kiosk_extension::remove<Rentables>(kiosk, cap);
}

/// 设置租赁
public fun setup_renting<T>(publisher: &Publisher, amount_bp: u64, ctx: &mut TxContext) {
    let (transfer_policy, policy_cap) = transfer_policy::new<T>(publisher, ctx);

    let protected_tp = ProtectedTP {
        id: object::new(ctx),
        transfer_policy,
        policy_cap,
    };

    let rental_policy = RentalPolicy<T> {
        id: object::new(ctx),
        balance: balance::zero(),
        amount_bp,
    };

    transfer::share_object(protected_tp);
    transfer::share_object(rental_policy);
}

public fun list<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    protected_tp: &ProtectedTP<T>,
    item_id: ID,
    duration: u64,
    price_per_day: u64,
    ctx: &mut TxContext,
) {
    assert!(kiosk_extension::is_installed<Rentables>(kiosk), EExtensionNotInstalled);

    kiosk.set_owner(cap, ctx);
    kiosk.list<T>(cap, item_id, 0);

    let coin = coin::zero<SUI>(ctx);
    let (object, request) = kiosk.purchase<T>(item_id, coin);

    let (_item, _paid, _form) = protected_tp.transfer_policy.confirm_request(request);

    let rentable = Rentable {
        object,
        duration,
        start_date: option::none<u64>(),
        price_per_day,
        kiosk_id: object::id(kiosk),
    };

    place_in_bag<T, Listed>(kiosk, Listed { id: item_id }, rentable);
}

public fun delist<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    transfer_policy: &TransferPolicy<T>,
    item_id: ID,
    _: &mut TxContext,
) {
    assert!(kiosk.has_access(cap), ENotOwner);

    let rentable = take_from_bag<T, Listed>(kiosk, Listed { id: item_id });
    let Rentable {
        object,
        duration: _,
        start_date: _,
        price_per_day: _,
        kiosk_id: _,
    } = rentable;

    if (has_rule<T, LockRule>(transfer_policy)) {
        kiosk.lock(cap, transfer_policy, object);
    } else {
        kiosk.place(cap, object);
    }
}

public fun rent<T: key + store>(
    renter_kiosk: &mut Kiosk,
    borrower_kiosk: &mut Kiosk,
    rental_policy: &mut RentalPolicy<T>,
    item_id: ID,
    mut coin: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(kiosk_extension::is_installed<Rentables>(borrower_kiosk), EExtensionNotInstalled);

    let mut rentable = take_from_bag<T, Listed>(renter_kiosk, Listed { id: item_id });

    let max_price_per_day = MAX_VALUE_U64 / rentable.duration;
    assert!(rentable.price_per_day <= max_price_per_day, ETotalPriceOverflow);

    let total_price = rentable.price_per_day * rentable.duration;
    let coin_value = coin.value();
    assert!(coin_value == total_price, ENotEnoughCoins);

    let mut fees_amount = coin_value as u128;
    fees_amount = fees_amount * (rental_policy.amount_bp as u128);
    fees_amount = fees_amount / (MAX_BASIS_POINTS as u128);

    let fees = coin.split(fees_amount as u64, ctx);
    coin::put(&mut rental_policy.balance, fees);
    transfer::public_transfer(coin, renter_kiosk.owner());
    rentable.start_date.fill(clock.timestamp_ms());

    place_in_bag<T, Rented>(borrower_kiosk, Rented { id: item_id }, rentable);
}

public fun borrow<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    item_id: ID,
    _ctx: &mut TxContext,
): &T {
    assert!(kiosk.has_access(cap), ENotOwner);

    let ext_storage_mut = kiosk_extension::storage_mut(Rentables {}, kiosk);
    let rentable: &Rentable<T> = &ext_storage_mut[Rented { id: item_id }];
    &rentable.object
}

public fun borrow_val<T: key + store>(
    kiosk: &mut Kiosk,
    cap: &KioskOwnerCap,
    item_id: ID,
    _ctx: &mut TxContext,
): (T, Promise) {
    assert!(kiosk.has_access(cap), ENotOwner);
    let borrower_kiosk = object::id(kiosk);

    let rentable = take_from_bag<T, Rented>(kiosk, Rented { id: item_id });

    let promise = Promise {
        item: Rented { id: item_id },
        duration: rentable.duration,
        start_date: *option::borrow(&rentable.start_date),
        price_per_day: rentable.price_per_day,
        renter_kiosk: rentable.kiosk_id,
        borrower_kiosk,
    };

    let Rentable {
        object,
        duration: _,
        start_date: _,
        price_per_day: _,
        kiosk_id: _,
    } = rentable;

    (object, promise)
}

public fun return_val<T: key + store>(
    kiosk: &mut Kiosk,
    object: T,
    promise: Promise,
    _ctx: &mut TxContext,
) {
    assert!(kiosk_extension::is_installed<Rentables>(kiosk), EExtensionNotInstalled);

    let Promise {
        item,
        duration,
        start_date,
        price_per_day,
        renter_kiosk,
        borrower_kiosk,
    } = promise;

    let kiosk_id = object::id(kiosk);
    assert!(kiosk_id == borrower_kiosk, EInvalidKiosk);

    let rentable = Rentable {
        object,
        duration,
        start_date: option::some(start_date),
        price_per_day,
        kiosk_id: renter_kiosk,
    };

    place_in_bag(kiosk, item, rentable);
}

public fun reclaim<T: key + store>(
    renter_kiosk: &mut Kiosk,
    borrower_kiosk: &mut Kiosk,
    transfer_policy: &TransferPolicy<T>,
    clock: &Clock,
    item_id: ID,
    _ctx: &mut TxContext,
) {
    assert!(kiosk_extension::is_installed<Rentables>(renter_kiosk), EExtensionNotInstalled);

    let rentable = take_from_bag<T, Rented>(borrower_kiosk, Rented { id: item_id });

    let Rentable {
        object,
        duration,
        start_date,
        price_per_day: _,
        kiosk_id,
    } = rentable;

    assert!(object::id(renter_kiosk) == kiosk_id, EInvalidKiosk);

    let start_date_ms = *option::borrow(&start_date);
    let current_timestamp = clock.timestamp_ms();
    let final_timestamp = start_date_ms + duration * SECONDS_IN_A_DAY;

    assert!(current_timestamp > final_timestamp, ERentingPeriodNotOver);

    if (transfer_policy.has_rule<T, LockRule>()) {
        kiosk_extension::lock<Rentables, T>(
            Rentables {},
            renter_kiosk,
            object,
            transfer_policy,
        );
    } else {
        kiosk_extension::place<Rentables, T>(
            Rentables {},
            renter_kiosk,
            object,
            transfer_policy,
        );
    };
}

fun take_from_bag<T: key + store, Key: store + copy + drop>(
    kiosk: &mut Kiosk,
    item: Key,
): Rentable<T> {
    let ext_storage_mut = kiosk_extension::storage_mut(Rentables {}, kiosk);
    assert!(bag::contains(ext_storage_mut, item), EObjectNotExist);
    bag::remove<Key, Rentable<T>>(
        ext_storage_mut,
        item,
    )
}

fun place_in_bag<T: key + store, Key: store + copy + drop>(
    kiosk: &mut Kiosk,
    item: Key,
    rentable: Rentable<T>,
) {
    let ext_storage_mut = kiosk_extension::storage_mut(Rentables {}, kiosk);
    bag::add(ext_storage_mut, item, rentable);
}
