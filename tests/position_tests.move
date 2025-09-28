#[test_only]
module outcomes::position_tests;

use outcomes::position;

public struct TEST has drop {}

#[test]
fun test_position_split() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let mut pos = position::create_for_testing<TEST>(market_id, 0, 100, ctx);
    let split_pos = pos.split(30, ctx);

    assert!(pos.value() == 70);
    assert!(split_pos.value() == 30);
    assert!(pos.outcome_index() == split_pos.outcome_index());

    pos.destroy_for_testing();
    split_pos.destroy_for_testing();
}

#[test]
fun test_position_join() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let mut pos1 = position::create_for_testing<TEST>(market_id, 0, 100, ctx);
    let pos2 = position::create_for_testing<TEST>(market_id, 0, 50, ctx);

    pos1.join(pos2);
    assert!(pos1.value() == 150);

    pos1.destroy_for_testing();
}

#[test]
fun test_destroy_zero() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let pos = position::create_for_testing<TEST>(market_id, 0, 0, ctx);
    pos.destroy_zero(); // Should succeed
}

#[test]
fun test_balance_conversion() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let pos = position::create_for_testing<TEST>(market_id, 0, 100, ctx);
    let balance = pos.into_balance();
    let new_pos = position::from_balance(balance, ctx);

    assert!(new_pos.value() == 100);
    assert!(new_pos.outcome_index() == 0);
    assert!(new_pos.market_id() == market_id);

    new_pos.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = position::EInsufficientOutcomeValue)]
fun test_split_insufficient() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let mut pos = position::create_for_testing<TEST>(market_id, 0, 50, ctx);
    let _split = pos.split(100, ctx); // Should fail

    pos.destroy_for_testing();
    _split.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = position::EMarketOutcomeMismatch)]
fun test_join_different_markets() {
    let ctx = &mut sui::tx_context::dummy();
    let market1 = object::id_from_address(@0x1);
    let market2 = object::id_from_address(@0x2);

    let mut pos1 = position::create_for_testing<TEST>(market1, 0, 100, ctx);
    let pos2 = position::create_for_testing<TEST>(market2, 0, 50, ctx);

    pos1.join(pos2); // Should fail

    pos1.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = position::EPositionNotZero)]
fun test_destroy_non_zero() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let pos = position::create_for_testing<TEST>(market_id, 0, 100, ctx);
    pos.destroy_zero(); // Should fail
}
