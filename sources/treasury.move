/// Treasury management for outcome tokens
/// 
/// This module manages the supply and minting/burning of outcome positions.
/// Each market gets one TreasuryCap that controls all outcome minting for that market.
/// 
/// Key features:
/// - Witness-based treasury creation (type ownership)
/// - Market binding via UID reference  
/// - Per-outcome supply tracking
/// - Overflow protection in minting
/// - Market isolation guarantees
module outcomes::treasury;

use outcomes::position::{Self, Position};

/// Supply tracking for a single outcome
/// Tracks how many tokens have been minted for this specific outcome
public struct Supply<phantom T> has store {
    /// Total amount of tokens minted for this outcome
    value: u64,
    /// Which outcome this tracks (0, 1, 2, etc.)
    outcome_index: u64,
}

/// Treasury capability that controls minting and burning for a market
/// 
/// The holder of this object can mint and burn outcome positions.
/// Each market should have exactly one TreasuryCap.
/// 
/// Security features:
/// - Created with witness pattern (proves type ownership)
/// - Bound to specific market via market_id
/// - Tracks supplies to prevent unauthorized inflation
public struct TreasuryCap<phantom T> has key, store {
    /// Unique identifier for this treasury
    id: UID,
    /// ID of the market this treasury belongs to
    market_id: ID,
    /// Supply tracking for each outcome (indexed by outcome_index)
    supplies: vector<Supply<T>>,
}

/// Error codes
const EInvalidOutcomeIndex: u64 = 0;
const EMarketOutcomeMismatch: u64 = 1;
const EOutcomeSupplyUnderflow: u64 = 2;
const EOutcomeSupplyOverflow: u64 = 3;

/// Create a new treasury for a market
/// 
/// Uses witness pattern to ensure only the type owner can create treasuries.
/// The market UID binding ensures positions can only be burned by the correct market.
/// 
/// # Arguments
/// * `_witness` - Witness proving caller owns type T (consumed)
/// * `market` - Reference to the market object (for binding)
/// * `num_outcomes` - Number of possible outcomes (e.g., 2 for YES/NO)
/// * `ctx` - TxContext
/// 
/// # Returns
/// * `TreasuryCap<T>` - Treasury capability for this market
/// 
/// # Security
/// - Witness pattern prevents unauthorized treasury creation
/// - Market UID binding prevents cross-market position abuse
/// - Supply vector initialized with zeros for each outcome
public fun create_treasury<T: drop>(
    _witness: T,
    market: &UID,
    num_outcomes: u64,
    ctx: &mut TxContext,
): TreasuryCap<T> {
    let supplies = vector::tabulate!(num_outcomes, |i| Supply { outcome_index: i, value: 0 });
    TreasuryCap { id: object::new(ctx), supplies, market_id: market.to_inner() }
}

/// Mint new outcome positions
/// 
/// Creates new position tokens for a specific outcome. Increases the supply
/// tracking for that outcome. Includes overflow protection.
/// 
/// # Arguments
/// * `treasury` - Treasury capability (proves authorization to mint)
/// * `outcome_index` - Which outcome to mint (0, 1, 2, etc.)
/// * `value` - Amount of tokens to mint
/// * `ctx` - TxContext
/// 
/// # Returns
/// * `Position<T>` - New position with the minted tokens
/// 
/// # Aborts
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
/// * `EOutcomeSupplyOverflow` - If minting would cause u64 overflow
public fun mint<T>(
    treasury: &mut TreasuryCap<T>,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Position<T> {
    assert!(outcome_index < treasury.supplies.length(), EInvalidOutcomeIndex);

    let supply = &mut treasury.supplies[outcome_index];
    assert!(value < (u64_max!() - supply.value), EOutcomeSupplyOverflow);

    supply.value = supply.value + value;
    position::new(treasury.market_id, outcome_index, value, ctx)
}

/// Burn outcome positions
/// 
/// Destroys position tokens and decreases the supply tracking.
/// Ensures the position belongs to this treasury's market.
/// 
/// # Arguments
/// * `treasury` - Treasury capability (proves authorization to burn)
/// * `position` - Position to burn (consumed)
/// 
/// # Returns
/// * `u64` - Amount of tokens that were burned
/// 
/// # Aborts
/// * `EMarketOutcomeMismatch` - If position belongs to different market
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes  
/// * `EOutcomeSupplyUnderflow` - If trying to burn more than current supply
public fun burn<T>(treasury: &mut TreasuryCap<T>, position: Position<T>): u64 {
    let (market_id, outcome_index, value) = position.destroy();

    assert!(market_id == treasury.market_id, EMarketOutcomeMismatch);
    assert!(outcome_index < treasury.supplies.length(), EInvalidOutcomeIndex);

    let supply = &mut treasury.supplies[outcome_index];
    assert!(supply.value >= value, EOutcomeSupplyUnderflow);

    supply.value = supply.value - value;
    value
}

/// Get total supply for a specific outcome
/// 
/// # Arguments
/// * `treasury` - Treasury to query
/// * `outcome_index` - Which outcome (0, 1, 2, etc.)
/// 
/// # Returns
/// * `u64` - Total tokens minted for this outcome
/// 
/// # Aborts
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
public fun total_supply<T>(treasury: &TreasuryCap<T>, outcome_index: u64): u64 {
    assert!(outcome_index < treasury.supplies.length(), EInvalidOutcomeIndex);
    treasury.supplies[outcome_index].value
}

/// Get supply values for all outcomes
/// 
/// # Arguments
/// * `treasury` - Treasury to query
/// 
/// # Returns
/// * `vector<u64>` - Supply for each outcome [outcome0_supply, outcome1_supply, ...]
public fun supply_values<T>(treasury: &TreasuryCap<T>): vector<u64> {
    treasury.supplies.map_ref!(|supply| supply.value)
}

/// Get number of possible outcomes for this market
/// 
/// # Arguments
/// * `treasury` - Treasury to query
/// 
/// # Returns
/// * `u64` - Number of outcomes (e.g., 2 for YES/NO)
public fun num_outcomes<T>(treasury: &TreasuryCap<T>): u64 {
    treasury.supplies.length()
}

/// Get the market ID this treasury belongs to
/// 
/// # Arguments
/// * `treasury` - Treasury to query
/// 
/// # Returns
/// * `ID` - Market ID this treasury was created for
public fun market_id<T>(treasury: &TreasuryCap<T>): ID {
    treasury.market_id
}

/// Helper macro for u64 maximum value
/// Used in overflow protection
macro fun u64_max(): u64 {
    18_446_744_073_709_551_615
}