#[test_only]
module satoshi_flip::test_ticket;

use satoshi_flip::ticket::{Ticket, create_ticket, withdraw as ticket_withdraw};
use sui::sui::SUI;
use sui::test_scenario;
use sui::test_utils::assert_eq;

#[test]
fun test_ticket_lifecycle() {
    let user = @0xa;
    let mut scenario_val = test_scenario::begin(user);
    let scenario = &mut scenario_val;

    test_scenario::next_tx(scenario, user);
    {
        let coin =
            sui::coin::mint_for_testing<SUI>(
                1000000, 
                test_scenario::ctx(scenario)
            );
        create_ticket(coin, test_scenario::ctx(scenario));
    };

    test_scenario::next_tx(scenario, user);
    {
        let ticket = test_scenario::take_from_sender<Ticket>(scenario);
        assert_eq(ticket.balance(), 1000000);
        test_scenario::return_to_sender(scenario, ticket);
    };

    test_scenario::next_tx(scenario, user);
    {
        let ticket = test_scenario::take_from_sender<Ticket>(scenario);
        ticket_withdraw(ticket, test_scenario::ctx(scenario));
    };

    test_scenario::end(scenario_val);
}
