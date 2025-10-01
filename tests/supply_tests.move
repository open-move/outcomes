#[test_only]
module outcomes::supply_tests;

use outcomes::supply;

public struct TEST has drop {}

#[test]
fun test_supply_creation() {
    let ctx = &mut sui::tx_context::dummy();
    let mut market_uid = sui::object::new(ctx);
    let market_id = market_uid.to_inner();

    let (supply_manager, cap) = supply::create(TEST {}, &mut market_uid, 2);

    assert!(supply_manager.num_outcomes() == 2);
    assert!(supply_manager.market_id() == market_id);
    assert!(supply_manager.total_supply(0) == 0);
    assert!(supply_manager.total_supply(1) == 0);

    let supplies = supply_manager.supply_values();
    assert!(supplies.length() == 2);
    assert!(supplies[0] == 0);
    assert!(supplies[1] == 0);

    market_uid.delete();
    sui::test_utils::destroy(supply_manager);
    sui::test_utils::destroy(cap);
}

#[test]
fun test_mint_and_burn() {
    let ctx = &mut sui::tx_context::dummy();
    let mut market_uid = sui::object::new(ctx);
    let (mut supply_manager, cap) = supply::create(TEST {}, &mut market_uid, 2);

    // Mint positions
    let pos1 = supply::mint(&cap, &mut supply_manager, 0, 100, ctx);
    let pos2 = supply::mint(&cap, &mut supply_manager, 1, 50, ctx);

    assert!(supply_manager.total_supply(0) == 100);
    assert!(supply_manager.total_supply(1) == 50);

    // Burn positions
    let burned1 = supply::burn(&cap, &mut supply_manager, pos1);
    let burned2 = supply::burn(&cap, &mut supply_manager, pos2);

    assert!(burned1 == 100);
    assert!(burned2 == 50);
    assert!(supply_manager.total_supply(0) == 0);
    assert!(supply_manager.total_supply(1) == 0);

    market_uid.delete();
    sui::test_utils::destroy(supply_manager);
    sui::test_utils::destroy(cap);
}

#[test]
fun test_multiple_mints() {
    let ctx = &mut sui::tx_context::dummy();
    let mut market_uid = sui::object::new(ctx);
    let (mut supply_manager, cap) = supply::create(TEST {}, &mut market_uid, 2);

    let pos1 = supply::mint(&cap, &mut supply_manager, 0, 100, ctx);
    let pos2 = supply::mint(&cap, &mut supply_manager, 0, 50, ctx);
    let pos3 = supply::mint(&cap, &mut supply_manager, 0, 25, ctx);

    assert!(supply_manager.total_supply(0) == 175);

    supply::burn(&cap, &mut supply_manager, pos1);
    supply::burn(&cap, &mut supply_manager, pos2);
    supply::burn(&cap, &mut supply_manager, pos3);

    assert!(supply_manager.total_supply(0) == 0);

    market_uid.delete();
    sui::test_utils::destroy(supply_manager);
    sui::test_utils::destroy(cap);
}

#[test]
#[expected_failure(abort_code = supply::EInvalidOutcomeIndex)]
fun test_mint_invalid_outcome() {
    let ctx = &mut sui::tx_context::dummy();
    let mut market_uid = sui::object::new(ctx);
    let (mut supply_manager, cap) = supply::create(TEST {}, &mut market_uid, 2);

    let pos = supply::mint(&cap, &mut supply_manager, 2, 100, ctx); // Should fail

    market_uid.delete();
    sui::test_utils::destroy(supply_manager);
    sui::test_utils::destroy(cap);
    outcomes::position::destroy_for_testing(pos);
}

#[test]
#[expected_failure(abort_code = supply::EMarketOutcomeMismatch)]
fun test_burn_wrong_market() {
    let ctx = &mut sui::tx_context::dummy();
    let mut market_uid1 = sui::object::new(ctx);
    let mut market_uid2 = sui::object::new(ctx);

    let (mut supply1_manager, cap1) = supply::create(TEST {}, &mut market_uid1, 2);
    let (mut supply2_manager, cap2) = supply::create(TEST {}, &mut market_uid2, 2);

    let pos = supply::mint(&cap1, &mut supply1_manager, 0, 100, ctx);
    supply::burn(&cap2, &mut supply2_manager, pos); // Should fail - wrong market

    market_uid1.delete();
    market_uid2.delete();
    sui::test_utils::destroy(supply1_manager);
    sui::test_utils::destroy(supply2_manager);
    sui::test_utils::destroy(cap1);
    sui::test_utils::destroy(cap2);
}

#[test]
#[expected_failure(abort_code = supply::EInvalidOutcomeIndex)]
fun test_total_supply_invalid() {
    let ctx = &mut sui::tx_context::dummy();
    let mut market_uid = sui::object::new(ctx);
    let (supply_manager, cap) = supply::create(TEST {}, &mut market_uid, 2);

    let _supply = supply_manager.total_supply(5); // Should fail

    market_uid.delete();
    sui::test_utils::destroy(supply_manager);
    sui::test_utils::destroy(cap);
}
