#[test_only]
module escrow::lock_tests;

use escrow::lock::{lock, unlock, ELockKeyMismatch};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

fun test_coin(ts: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(42, ts.ctx())
}

#[test]
fun test_lock_unlock() {
    let mut ts = ts::begin(@0xA);
    let coin = test_coin(&mut ts);

    let (lock, key) = lock(coin, ts.ctx());
    let coin = lock.unlock(key);

    coin.burn_for_testing();
    ts.end();
}

#[test]
#[expected_failure(abort_code = ELockKeyMismatch)]
fun test_lock_key_mismatch() {
    let mut ts = ts::begin(@0xA);
    let coin = test_coin(&mut ts);
    let another_coin = test_coin(&mut ts);
    let (l, _k) = lock(coin, ts.ctx());
    let (_l, k) = lock(another_coin, ts.ctx());

    let _key = l.unlock(k);
    abort 1337
}
