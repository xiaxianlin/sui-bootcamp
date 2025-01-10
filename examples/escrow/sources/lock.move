module escrow::lock;

use sui::dynamic_object_field as dof;
use sui::event;

public struct LockedObjectKey has copy, drop, store {}

public struct Locked<phantom T: key + store> has key, store {
    id: UID,
    key: ID,
}

public struct Key has key, store {
    id: UID,
}

const ELockKeyMismatch: u64 = 0;

/// 锁定后生成一个一次性的密钥
public fun lock<T: key + store>(obj: T, ctx: &mut TxContext): (Locked<T>, Key) {
    // 创建密钥
    let key = Key { id: object::new(ctx) };

    // 创建锁，把密钥加入锁中
    let mut lock = Locked {
        id: object::new(ctx),
        key: object::id(&key),
    };

    event::emit(LockCreated {
        lock_id: object::id(&lock),
        key_id: object::id(&key),
        creator: ctx.sender(),
        item_id: object::id(&obj),
    });

    // 将交易对象添加到锁里面
    dof::add(&mut lock.id, LockedObjectKey {}, obj);

    (lock, key)
}

/// 解锁后密钥失效
public fun unlock<T: key + store>(mut locked: Locked<T>, key: Key): T {
    assert!(locked.key == object::id(&key), ELockKeyMismatch);

    // 销毁密钥
    let Key { id } = key;
    id.delete();

    // 取出交易对象
    let obj = dof::remove<LockedObjectKey, T>(&mut locked.id, LockedObjectKey {});

    event::emit(LockDestroyed { lock_id: object::id(&locked) });

    // 销毁锁
    let Locked { id, key: _ } = locked;
    id.delete();

    obj
}

public struct LockCreated has copy, drop {
    lock_id: ID,
    key_id: ID,
    creator: address,
    item_id: ID,
}

public struct LockDestroyed has copy, drop {
    lock_id: ID,
}
