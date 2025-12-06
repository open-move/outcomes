#[test_only]
module outcomes::share_tests;

use outcomes::share;

#[test]
fun test_share_split() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let mut shr = share::create_for_testing(market_id, 0, 100, ctx);
    let split_shr = shr.split(30, ctx);

    assert!(shr.value() == 70);
    assert!(split_shr.value() == 30);
    assert!(shr.outcome_index() == split_shr.outcome_index());

    shr.destroy_for_testing();
    split_shr.destroy_for_testing();
}

#[test]
fun test_share_join() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let mut shr1 = share::create_for_testing(market_id, 0, 100, ctx);
    let shr2 = share::create_for_testing(market_id, 0, 50, ctx);

    shr1.join(shr2);
    assert!(shr1.value() == 150);

    shr1.destroy_for_testing();
}

#[test]
fun test_destroy_zero() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let shr = share::create_for_testing(market_id, 0, 0, ctx);
    shr.destroy_zero(); // Should succeed
}

#[test]
fun test_balance_conversion() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let shr = share::create_for_testing(market_id, 0, 100, ctx);
    let balance = shr.into_balance();
    let new_shr = share::from_balance(balance, ctx);

    assert!(new_shr.value() == 100);
    assert!(new_shr.outcome_index() == 0);
    assert!(new_shr.market_id() == market_id);

    new_shr.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = share::EInsufficientOutcomeValue)]
fun test_split_insufficient() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let mut shr = share::create_for_testing(market_id, 0, 50, ctx);
    let _split = shr.split(100, ctx); // Should fail

    shr.destroy_for_testing();
    _split.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = share::EMarketOutcomeMismatch)]
fun test_join_different_markets() {
    let ctx = &mut sui::tx_context::dummy();
    let market1 = object::id_from_address(@0x1);
    let market2 = object::id_from_address(@0x2);

    let mut shr1 = share::create_for_testing(market1, 0, 100, ctx);
    let shr2 = share::create_for_testing(market2, 0, 50, ctx);

    shr1.join(shr2); // Should fail

    shr1.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = share::EShareNotZero)]
fun test_destroy_non_zero() {
    let ctx = &mut sui::tx_context::dummy();
    let market_id = object::id_from_address(@0x1);

    let shr = share::create_for_testing(market_id, 0, 100, ctx);
    shr.destroy_zero(); // Should fail
}
