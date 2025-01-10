module escrow::shared;

use escrow::lock::{Locked, Key};
use sui::dynamic_object_field as dof;
use sui::event;

/// 托管对象的 KEY
/// 用于动态存储托管对象
public struct EscrowedObjectKey has copy, drop, store {}

/// 托管对象
public struct Escrow<phantom T: key + store> has key, store {
    id: UID,
    /// 托管人地址
    sender: address,
    /// 接收人地址
    recipient: address,
    /// 需要的对象
    exchange_key: ID,
}

const EMismatchedSenderRecipient: u64 = 0;

const EMismatchedExchangeObject: u64 = 1;

/// 创建一个托管单
public fun create<T: key + store>(
    // 托管对象
    escrowed: T,
    exchange_key: ID,
    recipient: address,
    ctx: &mut TxContext,
) {
    // 生成托管单
    let mut escrow = Escrow<T> {
        id: object::new(ctx),
        sender: ctx.sender(),
        recipient,
        exchange_key,
    };

    event::emit(EscrowCreated {
        escrow_id: object::id(&escrow),
        key_id: exchange_key,
        sender: escrow.sender,
        recipient,
        item_id: object::id(&escrowed),
    });

    // 托管物品添加到托管单
    dof::add(&mut escrow.id, EscrowedObjectKey {}, escrowed);

    // 公开托管单
    transfer::public_share_object(escrow);
}

/// 交换托管对象
public fun swap<T: key + store, U: key + store>(
    // 托管单
    mut escrow: Escrow<T>,
    // 交换对象的密钥
    key: Key,
    // 交换对象的锁
    locked: Locked<U>,
    ctx: &TxContext,
): T {
    // 取出托管对象
    let escrowed = dof::remove<EscrowedObjectKey, T>(&mut escrow.id, EscrowedObjectKey {});

    let Escrow { id, sender, recipient, exchange_key } = escrow;
    // 判断接收人是否是调用人
    assert!(recipient == ctx.sender(), EMismatchedSenderRecipient);
    // 判断交换对象是否匹配
    assert!(exchange_key == object::id(&key), EMismatchedExchangeObject);
    // 解锁交易对象，并转移给接收人
    transfer::public_transfer(locked.unlock(key), sender);

    event::emit(EscrowSwapped { escrow_id: id.to_inner() });
    // 销毁托管单
    id.delete();

    escrowed
}

/// 取消托管，返还托管对象给托管人
public fun return_to_sender<T: key + store>(mut escrow: Escrow<T>, ctx: &TxContext): T {
    event::emit(EscrowCancelled { escrow_id: object::id(&escrow) });

    // 取出托管对象
    let escrowed = dof::remove<EscrowedObjectKey, T>(&mut escrow.id, EscrowedObjectKey {});

    let Escrow { id, sender, recipient: _, exchange_key: _ } = escrow;
    // 判断托管单是否调用人创建
    assert!(sender == ctx.sender(), EMismatchedSenderRecipient);
    // 销毁托管单
    id.delete();

    escrowed
}

public struct EscrowCreated has copy, drop {
    escrow_id: ID,
    key_id: ID,
    sender: address,
    recipient: address,
    item_id: ID,
}

public struct EscrowSwapped has copy, drop {
    escrow_id: ID,
}

public struct EscrowCancelled has copy, drop {
    escrow_id: ID,
}
