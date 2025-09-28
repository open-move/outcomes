/// Position management for outcome tokens
/// 
/// This module handles individual position objects that represent claims on specific
/// outcomes in prediction markets. Positions can be split, joined, and converted
/// between object and balance representations.
///
/// Key features:
/// - Market isolation via market_id binding
/// - Position arithmetic (split/join)
/// - Zero-value position cleanup
/// - Balance conversion utils
module outcomes::position;

/// Raw balance for an outcome position
/// Contains the actual balance without the position object wrapper
public struct Balance<phantom T> has store {
    /// Amount of tokens for this outcome
    value: u64,
    /// ID of the market this position belongs to (prevents cross-market use)
    market_id: ID,
    /// Which outcome this position represents (0, 1, 2, etc.)
    outcome_index: u64,
}

/// A position representing a claim on a specific outcome in a prediction market
/// 
/// Positions have `key + store` abilities making them:
/// - Transferable via sui::transfer::public_transfer
/// - Usable in wallets and explorers
/// - Composable and usable in other DeFi protocols
/// - Storable in other objects
public struct Position<phantom T> has key, store {
    id: UID,
    /// The actual balance
    balance: Balance<T>,
}

/// Error codes
const EInsufficientOutcomeValue: u64 = 0;
const EMarketOutcomeMismatch: u64 = 1;
const EPositionNotZero: u64 = 2;

/// Create a new position (package-only, called by treasury)
/// 
/// # Arguments
/// * `market_id` - ID of the market this position belongs to
/// * `outcome_index` - Which outcome (0, 1, 2, etc.)
/// * `value` - Amount of tokens
/// * `ctx` - TxContext for creating new object
public(package) fun new<T>(
    market_id: ID,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Position<T> {
    Position {
        id: object::new(ctx),
        balance: Balance { market_id, outcome_index, value },
    }
}

/// Destroy a position and return its components (package-only, called by treasury)
/// 
/// # Returns
/// * `market_id` - ID of the market
/// * `outcome_index` - Which outcome  
/// * `value` - Amount of tokens that was in the position
public(package) fun destroy<T>(position: Position<T>): (ID, u64, u64) {
    let Position { id, balance } = position;
    let Balance { market_id, outcome_index, value } = balance;
    id.delete();

    (market_id, outcome_index, value)
}

/// Split a position into two positions
/// 
/// Removes `value` amount from the original position and creates a new position 
/// with that amount. Both positions represent the same outcome in the same market.
/// 
/// # Arguments
/// * `position` - Position to split (modified in place)
/// * `value` - Amount to remove from original and put in new position
/// * `ctx` - TxContext for creating new position
/// 
/// # Aborts
/// * `EInsufficientOutcomeValue` - If position doesn't have enough tokens
public fun split<T>(position: &mut Position<T>, value: u64, ctx: &mut TxContext): Position<T> {
    assert!(position.balance.value >= value, EInsufficientOutcomeValue);

    position.balance.value = position.balance.value - value;

    Position {
        id: object::new(ctx),
        balance: Balance {
            value: value,
            market_id: position.balance.market_id,
            outcome_index: position.balance.outcome_index,
        },
    }
}

/// Join two positions of the same market and outcome
/// 
/// Adds the value from `other` to `position` and destroys `other`.
/// Both positions must be for the same market and outcome.
/// 
/// # Arguments
/// * `position` - Position to add to (modified in place)
/// * `other` - Position to consume (destroyed)
/// 
/// # Aborts
/// * `EMarketOutcomeMismatch` - If positions are from different markets or outcomes
public fun join<T>(position: &mut Position<T>, other: Position<T>) {
    let Position { id, balance } = other;
    let Balance { market_id, outcome_index, value } = balance;

    assert!(market_id == position.balance.market_id, EMarketOutcomeMismatch);
    assert!(outcome_index == position.balance.outcome_index, EMarketOutcomeMismatch);

    position.balance.value = position.balance.value + value;
    id.delete();
}

/// Destroy a position that has zero value
/// 
/// Used for cleanup - removes empty positions from the system.
/// Position must have exactly 0 tokens.
/// 
/// # Arguments
/// * `position` - Position to destroy
/// 
/// # Aborts
/// * `EPositionNotZero` - If position has non-zero value
public fun destroy_zero<T>(position: Position<T>) {
    let Position { id, balance } = position;
    let Balance { market_id: _, outcome_index: _, value } = balance;
    assert!(value == 0, EPositionNotZero);

    id.delete();
}

/// Get the token amount in a position
public fun value<T>(position: &Position<T>): u64 {
    position.balance.value
}

/// Get which outcome this position represents (0, 1, 2, etc.)
public fun outcome_index<T>(position: &Position<T>): u64 {
    position.balance.outcome_index
}

/// Get the market ID this position belongs to
public fun market_id<T>(position: &Position<T>): ID {
    position.balance.market_id
}

/// Convert a Position object to raw Balance
/// 
/// Destroys the Position wrapper and returns the underlying Balance.
/// Useful for storing balances in other structures.
/// 
/// # Arguments
/// * `position` - Position to convert
/// 
/// # Returns
/// * `Balance<T>` - Raw balance
public fun into_balance<T>(position: Position<T>): Balance<T> {
    let Position { id, balance } = position;
    id.delete();
    balance
}

/// Convert raw Balance to a Position object
/// 
/// Wraps a Balance in a new Position object with a fresh UID.
/// 
/// # Arguments
/// * `balance` - Raw balance
/// * `ctx` - TxContext for creating new object
/// 
/// # Returns
/// * `Position<T>` - New position object
public fun from_balance<T>(balance: Balance<T>, ctx: &mut TxContext): Position<T> {
    Position { id: object::new(ctx), balance }
}

#[test_only]
public fun create_for_testing<T>(
    market_id: ID,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Position<T> {
    new(market_id, outcome_index, value, ctx)
}

#[test_only]
public fun destroy_for_testing<T>(position: Position<T>): u64 {
    let (_, _, value) = destroy(position);
    value
}