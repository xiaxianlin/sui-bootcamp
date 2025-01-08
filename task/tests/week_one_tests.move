#[test_only]
module task::week_one_tests;

use task::week_one::{Self, State};
use std::string;
use sui::test_scenario;
use sui::test_utils::assert_eq;

//const ENotImplemented: u64 = 0;

#[test]
fun test_create_profile() {
    let user = @0xa;
    let mut scenario_val = test_scenario::begin(user);
    let scenario = &mut scenario_val;

    week_one::init_for_testing(test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, user);
    let name = string::utf8(b"Bob");
    let desc = string::utf8(b"degen");
    {
        let mut state = test_scenario::take_shared<State>(scenario);
        week_one::create_profile(
            name,
            desc,
            &mut state,
            test_scenario::ctx(scenario),
        );
        assert!(week_one::check_if_has_profile(user, &state), 0);
        test_scenario::return_shared(state);
    };

    let tx = test_scenario::next_tx(scenario, user);
    let expected_events_emitted = 1;
    assert_eq(
        test_scenario::num_user_events(&tx),
        expected_events_emitted,
    );

    test_scenario::end(scenario_val);
}

// #[test, expected_failure(abort_code = ::admin::week_one_tests::ENotImplemented)]
// fun test_week_one_fail() {
//     abort ENotImplemented
// }
