module review_rating::moderator;

public struct Moderator has key {
    id: UID,
}

public struct ModCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let mod_cap = ModCap { id: object::new(ctx) };
    transfer::transfer(mod_cap, ctx.sender());
}

public fun add_moderator(_: &ModCap, recipient: address, ctx: &mut TxContext) {
    let mod = Moderator { id: object::new(ctx) };
    transfer::transfer(mod, recipient);
}

public fun del_moderator(mod: Moderator) {
    let Moderator { id } = mod;
    id.delete();
}
