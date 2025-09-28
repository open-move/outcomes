#[test_only]
module outcomes::treasury_tests;

use outcomes::treasury;

public struct TEST has drop {}

#[test]
fun test_treasury_creation() {
    let ctx = &mut sui::tx_context::dummy();
    let market_uid = object::new(ctx);
    let market_id = market_uid.to_inner();

    let treasury = treasury::create_treasury(TEST {}, &market_uid, 2, ctx);

    assert!(treasury.num_outcomes() == 2);
    assert!(treasury.market_id() == market_id);
    assert!(treasury.total_supply(0) == 0);
    assert!(treasury.total_supply(1) == 0);

    let supplies = treasury.supply_values();
    assert!(supplies.length() == 2);
    assert!(supplies[0] == 0);
    assert!(supplies[1] == 0);

    market_uid.delete();
    sui::test_utils::destroy(treasury);
}

#[test]
fun test_mint_and_burn() {
    let ctx = &mut sui::tx_context::dummy();
    let market_uid = object::new(ctx);
    let mut treasury = treasury::create_treasury(TEST {}, &market_uid, 2, ctx);

    // Mint positions
    let pos1 = treasury.mint(0, 100, ctx);
    let pos2 = treasury.mint(1, 50, ctx);

    assert!(treasury.total_supply(0) == 100);
    assert!(treasury.total_supply(1) == 50);

    // Burn positions
    let burned1 = treasury.burn(pos1);
    let burned2 = treasury.burn(pos2);

    assert!(burned1 == 100);
    assert!(burned2 == 50);
    assert!(treasury.total_supply(0) == 0);
    assert!(treasury.total_supply(1) == 0);

    market_uid.delete();
    sui::test_utils::destroy(treasury);
}

#[test]
fun test_multiple_mints() {
    let ctx = &mut sui::tx_context::dummy();
    let market_uid = object::new(ctx);
    let mut treasury = treasury::create_treasury(TEST {}, &market_uid, 2, ctx);

    let pos1 = treasury.mint(0, 100, ctx);
    let pos2 = treasury.mint(0, 50, ctx);
    let pos3 = treasury.mint(0, 25, ctx);

    assert!(treasury.total_supply(0) == 175);

    treasury.burn(pos1);
    treasury.burn(pos2);
    treasury.burn(pos3);

    assert!(treasury.total_supply(0) == 0);

    market_uid.delete();
    sui::test_utils::destroy(treasury);
}

#[test]
#[expected_failure(abort_code = treasury::EInvalidOutcomeIndex)]
fun test_mint_invalid_outcome() {
    let ctx = &mut sui::tx_context::dummy();
    let market_uid = object::new(ctx);
    let mut treasury = treasury::create_treasury(TEST {}, &market_uid, 2, ctx);

    let pos = treasury.mint(2, 100, ctx); // Should fail

    market_uid.delete();
    sui::test_utils::destroy(treasury);
    pos.destroy_for_testing();
}

#[test]
#[expected_failure(abort_code = treasury::EMarketOutcomeMismatch)]
fun test_burn_wrong_market() {
    let ctx = &mut sui::tx_context::dummy();
    let market_uid1 = object::new(ctx);
    let market_uid2 = object::new(ctx);

    let mut treasury1 = treasury::create_treasury(TEST {}, &market_uid1, 2, ctx);
    let mut treasury2 = treasury::create_treasury(TEST {}, &market_uid2, 2, ctx);

    let pos = treasury1.mint(0, 100, ctx);
    treasury2.burn(pos); // Should fail - wrong market

    market_uid1.delete();
    market_uid2.delete();
    sui::test_utils::destroy(treasury1);
    sui::test_utils::destroy(treasury2);
}

#[test]
#[expected_failure(abort_code = treasury::EInvalidOutcomeIndex)]
fun test_total_supply_invalid() {
    let ctx = &mut sui::tx_context::dummy();
    let market_uid = object::new(ctx);
    let treasury = treasury::create_treasury(TEST {}, &market_uid, 2, ctx);

    let _supply = treasury.total_supply(5); // Should fail

    market_uid.delete();
    sui::test_utils::destroy(treasury);
}
