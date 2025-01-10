#[test_only]
module escrow::shared_tests;

use escrow::lock::{Self, Key, Locked};
use escrow::shared::{create, Escrow, EMismatchedExchangeObject, EMismatchedSenderRecipient};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self as ts, Scenario};

const ALICE: address = @0xA;
const BOB: address = @0xB;
const DIANE: address = @0xD;

fun test_coin(ts: &mut Scenario): Coin<SUI> {
    coin::mint_for_testing<SUI>(42, ts.ctx())
}

#[test]
fun test_successful_swap() {
    let mut ts = ts::begin(@0x0);

    let (i2, ik2) = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        (cid, kid)
    };

    let i1 = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        // 托管对象 c
        // 需要对象 ik2，被锁定的对象
        // 接收人是 BOB，接收对象是 c
        create(c, ik2, BOB, ts.ctx());
        cid
    };

    {
        ts.next_tx(BOB);
        // 拿到托管单
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        // 拿到托管对象的密钥
        let k2: Key = ts.take_from_sender();
        // 拿到托管对象的锁
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        // 使用密钥和锁在交易方法中拿到托管对象
        let c = escrow.swap(k2, l2, ts.ctx());
        // 讲托管对象转移给 BOB
        transfer::public_transfer(c, BOB);
    };
    ts.next_tx(@0x0);

    {
        let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, i2);
        ts::return_to_address(ALICE, c);
    };

    {
        let c: Coin<SUI> = ts.take_from_address_by_id(BOB, i1);
        ts::return_to_address(BOB, c);
    };

    ts::end(ts);
}

#[test]
#[expected_failure(abort_code = EMismatchedSenderRecipient)]
fun test_mismatch_sender() {
    let mut ts = ts::begin(@0x0);

    let ik2 = {
        ts.next_tx(DIANE);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, DIANE);
        transfer::public_transfer(k, DIANE);
        kid
    };

    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        create(c, ik2, BOB, ts.ctx());
    };

    {
        ts.next_tx(DIANE);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, DIANE);
    };

    abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_mismatch_object() {
    let mut ts = ts::begin(@0x0);

    {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
    };

    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        create(c, cid, BOB, ts.ctx());
    };

    {
        ts.next_tx(BOB);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, BOB);
    };

    abort 1337
}

#[test]
#[expected_failure(abort_code = EMismatchedExchangeObject)]
fun test_object_tamper() {
    let mut ts = ts::begin(@0x0);

    let ik2 = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        kid
    };

    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        create(c, ik2, BOB, ts.ctx());
    };

    {
        ts.next_tx(BOB);
        let k: Key = ts.take_from_sender();
        let l: Locked<Coin<SUI>> = ts.take_from_sender();
        let mut c = lock::unlock(l, k);

        let _dust = c.split(1, ts.ctx());
        let (l, k) = lock::lock(c, ts.ctx());
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let c = escrow.swap(k, l, ts.ctx());

        transfer::public_transfer(c, BOB);
    };

    abort 1337
}

#[test]
fun test_return_to_sender() {
    let mut ts = ts::begin(@0x0);

    let cid = {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        let cid = object::id(&c);
        let i = object::id_from_address(@0x0);
        create(c, i, BOB, ts.ctx());
        cid
    };

    {
        ts.next_tx(ALICE);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let c = escrow.return_to_sender(ts.ctx());

        transfer::public_transfer(c, ALICE);
    };

    ts.next_tx(@0x0);

    {
        let c: Coin<SUI> = ts.take_from_address_by_id(ALICE, cid);
        ts::return_to_address(ALICE, c)
    };

    ts::end(ts);
}

#[test]
#[expected_failure]
fun test_return_to_sender_failed_swap() {
    let mut ts = ts::begin(@0x0);

    let ik2 = {
        ts.next_tx(BOB);
        let c = test_coin(&mut ts);
        let (l, k) = lock::lock(c, ts.ctx());
        let kid = object::id(&k);
        transfer::public_transfer(l, BOB);
        transfer::public_transfer(k, BOB);
        kid
    };

    {
        ts.next_tx(ALICE);
        let c = test_coin(&mut ts);
        create(c, ik2, BOB, ts.ctx());
    };

    {
        ts.next_tx(ALICE);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let c = escrow.return_to_sender(ts.ctx());
        transfer::public_transfer(c, ALICE);
    };

    {
        ts.next_tx(BOB);
        let escrow: Escrow<Coin<SUI>> = ts.take_shared();
        let k2: Key = ts.take_from_sender();
        let l2: Locked<Coin<SUI>> = ts.take_from_sender();
        let c = escrow.swap(k2, l2, ts.ctx());

        transfer::public_transfer(c, BOB);
    };

    abort 1337
}
