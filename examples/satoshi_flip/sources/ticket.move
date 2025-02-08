module satoshi_flip::ticket;

use sui::balance::Balance;
use sui::bcs;
use sui::coin::Coin;
use sui::sui::SUI;

const ECallerNotMatch: u64 = 0;

public struct Ticket has key {
    id: UID,
    count: u64,
    owner: address,
    balance: Balance<SUI>,
}

public fun create_ticket(coin: Coin<SUI>, ctx: &mut TxContext) {
    let ticket = Ticket {
        id: object::new(ctx),
        count: 0,
        owner: ctx.sender(),
        balance: coin.into_balance(),
    };
    transfer::transfer(ticket, ctx.sender());
}

#[allow(lint(self_transfer))]
public fun withdraw(ticket: Ticket, ctx: &mut TxContext) {
    assert!(ctx.sender() == ticket.owner, ECallerNotMatch);
    let Ticket { id, count: _, owner: _, balance } = ticket;
    id.delete();
    transfer::public_transfer(balance.into_coin(ctx), ctx.sender());
}

public fun get_vrf_input(self: &mut Ticket): vector<u8> {
    let mut vrf_input = object::id_bytes(self);
    let count_to_bytes = bcs::to_bytes(&self.count);
    vrf_input.append(count_to_bytes);
    self.count = self.count + 1;
    vrf_input
}

public fun balance(self: &Ticket): u64 {
    self.balance.value()
}

public fun owner(self: &Ticket): address {
    self.owner
}

public(package) fun borrow_balance_mut(house_data: &mut Ticket): &mut Balance<SUI> {
    &mut house_data.balance
}
