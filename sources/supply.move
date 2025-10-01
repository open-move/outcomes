/// Supply management for outcome tokens
///
/// This module manages the supply and minting/burning of outcome positions.
/// Each market gets one SupplyManager that controls all outcome minting for that market.
///
/// Key features:
/// - Witness-based supply manager creation (type ownership)
/// - Market binding via UID reference
/// - Per-outcome supply tracking
/// - Overflow protection in minting
/// - Market isolation guarantees
module outcomes::supply;

use outcomes::position::{Self, Position};
use sui::derived_object;

/// Supply tracking for a single outcome
/// Tracks how many tokens have been minted for this specific outcome
public struct Supply<phantom T> has store {
    /// Total amount of tokens minted for this outcome
    value: u64,
    /// Which outcome this tracks (0, 1, 2, etc.)
    outcome_index: u64,
}

/// Supply manager that tracks outcome supplies for a market
///
/// This object contains the supply data and can be shared for read access.
/// Requires SupplyManagerCap for minting/burning operations.
///
/// Security features:
/// - Created with witness pattern (proves type ownership)
/// - Bound to specific market via market_id
/// - Tracks supplies to prevent unauthorized inflation
public struct SupplyManager<phantom T> has key, store {
    /// Unique identifier for this supply manager
    id: UID,
    /// ID of the market this supply manager belongs to
    market_id: ID,
    /// Supply tracking for each outcome (indexed by outcome_index)
    supplies: vector<Supply<T>>,
}

/// Capability to control a SupplyManager
///
/// The holder of this capability can mint and burn positions from the associated
/// SupplyManager. Each SupplyManager should have exactly one SupplyManagerCap.
///
/// Security features:
/// - Links to specific SupplyManager via supply_manager_id
/// - Can be kept private by market or transferred to delegates
/// - Required for all minting/burning operations
public struct SupplyManagerCap<phantom T> has key, store {
    /// Unique identifier for this capability
    id: UID,
    /// ID of the SupplyManager this capability controls
    supply_manager_id: ID,
}

public struct SupplyManagerKey() has copy, drop, store;
public struct SupplyManagerCapKey() has copy, drop, store;

/// Error codes
const EInvalidOutcomeIndex: u64 = 0;
const EMarketOutcomeMismatch: u64 = 1;
const EOutcomeSupplyUnderflow: u64 = 2;
const EOutcomeSupplyOverflow: u64 = 3;
const ECapSupplyManagerMismatch: u64 = 4;

/// Create a new supply manager and capability for a market
///
/// Uses witness pattern to ensure only the type owner can create supply managers.
/// The market UID binding ensures positions can only be burned by the correct market.
///
/// # Arguments
/// * `_witness` - Witness proving caller owns type T (consumed)
/// * `market` - Reference to the market object (for binding)
/// * `num_outcomes` - Number of possible outcomes (e.g., 2 for YES/NO)
/// * `ctx` - TxContext
///
/// # Returns
/// * `(SupplyManager<T>, SupplyManagerCap<T>)` - Supply manager and capability
///
/// # Security
/// - Witness pattern prevents unauthorized supply manager creation
/// - Market UID binding prevents cross-market position abuse
/// - Supply vector initialized with zeros for each outcome
/// - Capability links to specific supply manager
public fun create<T: drop>(
    _witness: T,
    market: &mut UID,
    num_outcomes: u64,
): (SupplyManager<T>, SupplyManagerCap<T>) {
    let supplies = vector::tabulate!(num_outcomes, |i| Supply { outcome_index: i, value: 0 });

    let mut supply_manager = SupplyManager {
        id: derived_object::claim(market, SupplyManagerKey()),
        supplies,
        market_id: market.to_inner(),
    };

    let supply_manager_cap = SupplyManagerCap {
        id: derived_object::claim(&mut supply_manager.id, SupplyManagerCapKey()),
        supply_manager_id: supply_manager.id.to_inner(),
    };

    (supply_manager, supply_manager_cap)
}

/// Mint new outcome positions
///
/// Creates new position tokens for a specific outcome. Increases the supply
/// tracking for that outcome. Includes overflow protection.
///
/// # Arguments
/// * `cap` - SupplyManagerCap (proves authorization to mint)
/// * `manager` - SupplyManager to mint from
/// * `outcome_index` - Which outcome to mint (0, 1, 2, etc.)
/// * `value` - Amount of tokens to mint
/// * `ctx` - TxContext
///
/// # Returns
/// * `Position<T>` - New position with the minted tokens
///
/// # Aborts
/// * `ECapSupplyManagerMismatch` - If cap doesn't match manager
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
/// * `EOutcomeSupplyOverflow` - If minting would cause u64 overflow
public fun mint<T>(
    cap: &SupplyManagerCap<T>,
    manager: &mut SupplyManager<T>,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Position<T> {
    assert!(cap.supply_manager_id == manager.id.to_inner(), ECapSupplyManagerMismatch);
    assert!(outcome_index < manager.supplies.length(), EInvalidOutcomeIndex);

    let supply = &mut manager.supplies[outcome_index];
    assert!(value < (u64_max!() - supply.value), EOutcomeSupplyOverflow);

    supply.value = supply.value + value;
    position::new(manager.market_id, outcome_index, value, ctx)
}

/// Burn outcome positions
///
/// Destroys position tokens and decreases the supply tracking.
/// Ensures the position belongs to this supply manager's market.
///
/// # Arguments
/// * `cap` - SupplyManagerCap (proves authorization to burn)
/// * `manager` - SupplyManager to burn from
/// * `position` - Position to burn (consumed)
///
/// # Returns
/// * `u64` - Amount of tokens that were burned
///
/// # Aborts
/// * `ECapSupplyManagerMismatch` - If cap doesn't match manager
/// * `EMarketOutcomeMismatch` - If position belongs to different market
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
/// * `EOutcomeSupplyUnderflow` - If trying to burn more than current supply
public fun burn<T>(
    cap: &SupplyManagerCap<T>,
    manager: &mut SupplyManager<T>,
    position: Position<T>,
): u64 {
    assert!(cap.supply_manager_id == manager.id.to_inner(), ECapSupplyManagerMismatch);

    let (market_id, outcome_index, value) = position.destroy();

    assert!(market_id == manager.market_id, EMarketOutcomeMismatch);
    assert!(outcome_index < manager.supplies.length(), EInvalidOutcomeIndex);

    let supply = &mut manager.supplies[outcome_index];
    assert!(supply.value >= value, EOutcomeSupplyUnderflow);

    supply.value = supply.value - value;
    value
}

/// Get total supply for a specific outcome
///
/// # Arguments
/// * `manager` - SupplyManager to query
/// * `outcome_index` - Which outcome (0, 1, 2, etc.)
///
/// # Returns
/// * `u64` - Total tokens minted for this outcome
///
/// # Aborts
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
public fun total_supply<T>(manager: &SupplyManager<T>, outcome_index: u64): u64 {
    assert!(outcome_index < manager.supplies.length(), EInvalidOutcomeIndex);
    manager.supplies[outcome_index].value
}

/// Get supply values for all outcomes
///
/// # Arguments
/// * `manager` - SupplyManager to query
///
/// # Returns
/// * `vector<u64>` - Supply for each outcome [outcome0_supply, outcome1_supply, ...]
public fun supply_values<T>(manager: &SupplyManager<T>): vector<u64> {
    manager.supplies.map_ref!(|supply| supply.value)
}

/// Get number of possible outcomes for this market
///
/// # Arguments
/// * `manager` - SupplyManager to query
///
/// # Returns
/// * `u64` - Number of outcomes (e.g., 2 for YES/NO)
public fun num_outcomes<T>(manager: &SupplyManager<T>): u64 {
    manager.supplies.length()
}

/// Get the market ID this supply manager belongs to
///
/// # Arguments
/// * `manager` - SupplyManager to query
///
/// # Returns
/// * `ID` - Market ID this supply manager was created for
public fun market_id<T>(manager: &SupplyManager<T>): ID {
    manager.market_id
}

/// Get the SupplyManager's own ID
///
/// # Arguments
/// * `manager` - SupplyManager to query
///
/// # Returns
/// * `ID` - The SupplyManager's unique ID
public fun id<T>(manager: &SupplyManager<T>): ID {
    manager.id.to_inner()
}

/// Get which SupplyManager this capability controls
///
/// # Arguments
/// * `cap` - SupplyManagerCap to query
///
/// # Returns
/// * `ID` - ID of the SupplyManager this cap can control
public fun supply_manager_id<T>(cap: &SupplyManagerCap<T>): ID {
    cap.supply_manager_id
}

/// Get the capability's own ID
///
/// # Arguments
/// * `cap` - SupplyManagerCap to query
///
/// # Returns
/// * `ID` - The capability's unique ID
public fun cap_id<T>(cap: &SupplyManagerCap<T>): ID {
    cap.id.to_inner()
}

/// Check if a capability can control a specific SupplyManager
///
/// # Arguments
/// * `cap` - SupplyManagerCap to check
/// * `manager` - SupplyManager to check against
///
/// # Returns
/// * `bool` - True if cap can control this manager
public fun is_manager_cap<T>(cap: &SupplyManagerCap<T>, manager: &SupplyManager<T>): bool {
    cap.supply_manager_id == manager.id.to_inner()
}

/// Helper macro for u64 maximum value
/// Used in overflow protection
macro fun u64_max(): u64 {
    18_446_744_073_709_551_615
}
