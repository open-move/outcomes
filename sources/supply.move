/// Supply management for outcome tokens
///
/// This module manages the supply and minting/burning of outcome shares.
/// Each market gets one SupplyState that controls all outcome minting for that market.
///
/// Key features:
/// - Witness-based supply state creation (type ownership)
/// - Market binding via UID reference
/// - Per-outcome supply tracking
/// - Overflow protection in minting
/// - Market isolation guarantees
module outcomes::supply;

use outcomes::share::{Self, Share};
use sui::derived_object;

/// Supply tracking for a single outcome
/// Tracks how many tokens have been minted for this specific outcome
public struct Supply has store {
    /// Total amount of tokens minted for this outcome
    value: u64,
    /// Which outcome this tracks (0, 1, 2, etc.)
    outcome_index: u64,
}

/// Supply state that tracks outcome supplies for a market
///
/// This object contains the supply data and can be shared for read access.
/// Requires SupplyCap for minting/burning operations.
///
/// Security features:
/// - Created with witness pattern (proves type ownership)
/// - Bound to specific market via market_id
/// - Tracks supplies to prevent unauthorized inflation
public struct SupplyState has key, store {
    /// Unique identifier for this supply state
    id: UID,
    /// ID of the market this supply state belongs to
    market_id: ID,
    /// Supply tracking for each outcome (indexed by outcome_index)
    supplies: vector<Supply>,
}

/// Capability to control a SupplyState
///
/// The holder of this capability can mint and burn shares from the associated
/// SupplyState. Each SupplyState should have exactly one SupplyCap.
///
/// Security features:
/// - Links to specific SupplyState via supply_state_id
/// - Can be kept private by market or transferred to delegates
/// - Required for all minting/burning operations
public struct SupplyCap has key, store {
    /// Unique identifier for this capability
    id: UID,
    /// ID of the SupplyState this capability controls
    supply_state_id: ID,
}

public struct SupplyStateKey() has copy, drop, store;
public struct SupplyCapKey() has copy, drop, store;

/// Error codes
const EInvalidOutcomeIndex: u64 = 0;
const EMarketOutcomeMismatch: u64 = 1;
const EOutcomeSupplyUnderflow: u64 = 2;
const EOutcomeSupplyOverflow: u64 = 3;
const ECapSupplyStateMismatch: u64 = 4;

/// Create a new supply state and capability for a market
///
/// Uses witness pattern to ensure only the type owner can create supply states.
/// The market UID binding ensures shares can only be burned by the correct market.
///
/// # Arguments
/// * `_witness` - Witness proving caller owns type T (consumed)
/// * `market` - Reference to the market object (for binding)
/// * `num_outcomes` - Number of possible outcomes (e.g., 2 for YES/NO)
///
/// # Returns
/// * `(SupplyState, SupplyCap)` - Supply state and capability
///
/// # Security
/// - Witness pattern prevents unauthorized supply state creation
/// - Market UID binding prevents cross-market share abuse
/// - Supply vector initialized with zeros for each outcome
/// - Capability links to specific supply state
public fun create<T: drop>(
    _witness: T,
    market: &mut UID,
    num_outcomes: u64,
): (SupplyState, SupplyCap) {
    let supplies = vector::tabulate!(num_outcomes, |i| Supply { outcome_index: i, value: 0 });

    let mut supply_state = SupplyState {
        id: derived_object::claim(market, SupplyStateKey()),
        supplies,
        market_id: market.to_inner(),
    };

    let supply_state_cap = SupplyCap {
        id: derived_object::claim(&mut supply_state.id, SupplyCapKey()),
        supply_state_id: supply_state.id.to_inner(),
    };

    (supply_state, supply_state_cap)
}

/// Mint new outcome shares
///
/// Creates new share tokens for a specific outcome. Increases the supply
/// tracking for that outcome. Includes overflow protection.
///
/// # Arguments
/// * `cap` - SupplyCap (proves authorization to mint)
/// * `state` - SupplyState to mint from
/// * `outcome_index` - Which outcome to mint (0, 1, 2, etc.)
/// * `value` - Amount of tokens to mint
/// * `ctx` - TxContext
///
/// # Returns
/// * `Share` - New share with the minted tokens
///
/// # Aborts
/// * `ECapSupplyStateMismatch` - If cap doesn't match state
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
/// * `EOutcomeSupplyOverflow` - If minting would cause u64 overflow
public fun mint(
    cap: &SupplyCap,
    state: &mut SupplyState,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Share {
    assert!(cap.supply_state_id == state.id.to_inner(), ECapSupplyStateMismatch);
    assert!(outcome_index < state.supplies.length(), EInvalidOutcomeIndex);
    state.mint_internal(outcome_index, value, ctx)
}

/// Mint one share per outcome.
///
/// Convenience wrapper to mint the same amount across all outcome indices.
/// Returns an empty vector when `num_outcomes == 0`.
///
/// # Aborts
/// * `ECapSupplyStateMismatch` - If cap doesn't match state
/// * `EOutcomeSupplyOverflow` - If any outcome mint would overflow
public fun mint_vec(
    cap: &SupplyCap,
    state: &mut SupplyState,
    value: u64,
    ctx: &mut TxContext,
): vector<Share> {
    assert!(cap.supply_state_id == state.id.to_inner(), ECapSupplyStateMismatch);
    vector::tabulate!(state.supplies.length(), |i| state.mint_internal(i, value, ctx))
}

/// Burn outcome shares
///
/// Destroys share tokens and decreases the supply tracking.
/// Ensures the share belongs to this supply state's market.
///
/// # Arguments
/// * `cap` - SupplyCap (proves authorization to burn)
/// * `state` - SupplyState to burn from
/// * `share` - Share to burn (consumed)
///
/// # Returns
/// * `u64` - Amount of tokens that were burned
///
/// # Aborts
/// * `ECapSupplyStateMismatch` - If cap doesn't match state
/// * `EMarketOutcomeMismatch` - If share belongs to different market
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
/// * `EOutcomeSupplyUnderflow` - If trying to burn more than current supply
public fun burn(cap: &SupplyCap, state: &mut SupplyState, share: Share): u64 {
    assert!(cap.supply_state_id == state.id.to_inner(), ECapSupplyStateMismatch);
    state.burn_internal(share)
}

/// Burn a vector of outcome shares.
///
/// Destroys each share and updates supply tracking. Does not enforce
/// one-per-outcome semantics; caller must ensure the vector is well-formed.
///
/// # Aborts
/// * `ECapSupplyStateMismatch` - If cap doesn't match state
/// * `EMarketOutcomeMismatch` - If any share belongs to a different market
/// * `EInvalidOutcomeIndex` - If a share references an invalid outcome
/// * `EOutcomeSupplyUnderflow` - If burning would underflow supply
public fun burn_vec(cap: &SupplyCap, state: &mut SupplyState, shares: vector<Share>) {
    assert!(cap.supply_state_id == state.id.to_inner(), ECapSupplyStateMismatch);
    shares.destroy!(|share| state.burn_internal(share))
}

/// Get total supply for a specific outcome
///
/// # Arguments
/// * `state` - SupplyState to query
/// * `outcome_index` - Which outcome (0, 1, 2, etc.)
///
/// # Returns
/// * `u64` - Total tokens minted for this outcome
///
/// # Aborts
/// * `EInvalidOutcomeIndex` - If outcome_index >= num_outcomes
public fun total_supply(state: &SupplyState, outcome_index: u64): u64 {
    assert!(outcome_index < state.supplies.length(), EInvalidOutcomeIndex);
    state.supplies[outcome_index].value
}

/// Get supply values for all outcomes
///
/// # Arguments
/// * `state` - SupplyState to query
///
/// # Returns
/// * `vector<u64>` - Supply for each outcome [outcome0_supply, outcome1_supply, ...]
public fun supply_values(state: &SupplyState): vector<u64> {
    state.supplies.map_ref!(|supply| supply.value)
}

/// Get number of possible outcomes for this market
///
/// # Arguments
/// * `state` - SupplyState to query
///
/// # Returns
/// * `u64` - Number of outcomes (e.g., 2 for YES/NO)
public fun num_outcomes(state: &SupplyState): u64 {
    state.supplies.length()
}

/// Get the market ID this supply state belongs to
///
/// # Arguments
/// * `state` - SupplyState to query
///
/// # Returns
/// * `ID` - Market ID this supply state was created for
public fun market_id(state: &SupplyState): ID {
    state.market_id
}

/// Get the SupplyState's own ID
///
/// # Arguments
/// * `state` - SupplyState to query
///
/// # Returns
/// * `ID` - The SupplyState's unique ID
public fun id(state: &SupplyState): ID {
    state.id.to_inner()
}

/// Get which SupplyState this capability controls
///
/// # Arguments
/// * `cap` - SupplyCap to query
///
/// # Returns
/// * `ID` - ID of the SupplyState this cap can control
public fun supply_state_id(cap: &SupplyCap): ID {
    cap.supply_state_id
}

/// Get the capability's own ID
///
/// # Arguments
/// * `cap` - SupplyCap to query
///
/// # Returns
/// * `ID` - The capability's unique ID
public fun cap_id(cap: &SupplyCap): ID {
    cap.id.to_inner()
}

/// Check if a capability can control a specific SupplyState
///
/// # Arguments
/// * `cap` - SupplyCap to check
/// * `state` - SupplyState to check against
///
/// # Returns
/// * `bool` - True if cap can control this state
public fun is_state_cap(cap: &SupplyCap, state: &SupplyState): bool {
    cap.supply_state_id == state.id.to_inner()
}

/// Internal mint helper.
///
/// Assumes the caller already validated cap/state linkage and outcome index.
/// Performs overflow-checked supply update and creates a new share.
fun mint_internal(
    state: &mut SupplyState,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Share {
    let supply = &mut state.supplies[outcome_index];
    assert!(value <= (u64_max!() - supply.value), EOutcomeSupplyOverflow);

    supply.value = supply.value + value;
    share::new(state.market_id, outcome_index, value, ctx)
}

/// Internal burn helper.
///
/// Assumes the caller already validated cap/state linkage.
/// Enforces market binding, outcome bounds, and supply underflow checks.
fun burn_internal(state: &mut SupplyState, share: Share): u64 {
    let (market_id, outcome_index, value) = share.destroy();

    assert!(market_id == state.market_id, EMarketOutcomeMismatch);
    assert!(outcome_index < state.supplies.length(), EInvalidOutcomeIndex);

    let supply = &mut state.supplies[outcome_index];
    assert!(supply.value >= value, EOutcomeSupplyUnderflow);

    supply.value = supply.value - value;
    value
}

/// Helper macro for u64 maximum value
/// Used in overflow protection
macro fun u64_max(): u64 {
    18_446_744_073_709_551_615
}
