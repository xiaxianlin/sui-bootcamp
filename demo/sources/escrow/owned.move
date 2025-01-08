module demo::escrow_owned;

use demo::escrow_lock::{Key, Locked};

public struct Escrow<T: key + store> has key {
    id: UID,
    sender: address,
    recipient: address,
    exchange_key: ID,
    escrowed_key: ID,
    escrowed: T,
}

const EMismatchedSenderRecipient: u64 = 0;

const EMismatchedExchangeObject: u64 = 1;

public fun create<T: key + store>(
    key: Key,
    locked: Locked<T>,
    exchange_key: ID,
    recipient: address,
    custodian: address,
    ctx: &mut TxContext,
) {
    let escrow = Escrow {
        id: object::new(ctx),
        sender: ctx.sender(),
        recipient,
        exchange_key,
        escrowed_key: object::id(&key),
        escrowed: locked.unlock(key),
    };
    transfer::transfer(escrow, custodian);
}

public fun swap<T: key + store, U: key + store>(obj1: Escrow<T>, obj2: Escrow<U>) {
    let Escrow {
        id: id1,
        sender: sender1,
        recipient: recipient1,
        exchange_key: exchange_key1,
        escrowed_key: escrowed_key1,
        escrowed: escrowed1,
    } = obj1;

    let Escrow {
        id: id2,
        sender: sender2,
        recipient: recipient2,
        exchange_key: exchange_key2,
        escrowed_key: escrowed_key2,
        escrowed: escrowed2,
    } = obj2;

    id1.delete();
    id2.delete();

    assert!(sender1 == recipient2, EMismatchedSenderRecipient);
    assert!(sender2 == recipient1, EMismatchedSenderRecipient);

    assert!(escrowed_key1 == exchange_key2, EMismatchedExchangeObject);
    assert!(escrowed_key2 == exchange_key1, EMismatchedExchangeObject);

    transfer::public_transfer(escrowed1, recipient1);
    transfer::public_transfer(escrowed2, recipient2);
}

public fun return_to_sender<T: key + store>(obj: Escrow<T>) {
    let Escrow {
        id,
        sender,
        recipient: _,
        exchange_key: _,
        escrowed_key: _,
        escrowed,
    } = obj;
    id.delete();
    transfer::public_transfer(escrowed, sender);
}
