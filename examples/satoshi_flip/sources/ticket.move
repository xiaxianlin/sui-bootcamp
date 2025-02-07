module satoshi_flip::ticket;

use sui::bcs;

public struct Ticket has key {
    id: UID,
    count: u64,
    owner: address,
}

public fun create_ticket(ctx: &mut TxContext) {
    let ticket = Ticket { id: object::new(ctx), count: 0, owner: ctx.sender() };
    transfer::transfer(ticket, ctx.sender());
}

public fun remove_ticket(ticket: Ticket) {
    let Ticket { id, count: _, owner: _ } = ticket;
    id.delete();
}

public fun get_vrf_input(self: &mut Ticket): vector<u8> {
    let mut vrf_input = object::id_bytes(self);
    let count_to_bytes = bcs::to_bytes(&count(self));
    vrf_input.append(count_to_bytes);
    self.count = self.count + 1;
    vrf_input
}

public fun count(self: &Ticket): u64 {
    self.count
}

public fun owner(self: &Ticket): address {
    self.owner
}
