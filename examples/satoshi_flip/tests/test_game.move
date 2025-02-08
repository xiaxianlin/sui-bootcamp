#[test_only]
module satoshi_flip::test_game;

use satoshi_flip::game;
use satoshi_flip::test_common as tc;
use sui::test_scenario;

#[test]
fun test_house_win() {
    let house = @0xCAFE;
    let player = @0xDECAF;

    let mut scenario_val = test_scenario::begin(house);
    let scenario = &mut scenario_val;

    {
        tc::fund_addresses(
            scenario,
            house,
            player,
            tc::get_initial_house_balance(),
            tc::get_initial_player_balance(),
        );
    };

    tc::init_game(scenario, house);

    scenario_val.end();
}

#[test]
fun test_player_win() {}
