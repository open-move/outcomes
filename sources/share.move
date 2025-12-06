/// Share management for outcome tokens
///
/// This module handles individual share objects that represent claims on specific
/// outcomes in prediction markets. Shares can be split, joined, and converted
/// between object and balance representations.
///
/// Key features:
/// - Market isolation via market_id binding
/// - Share arithmetic (split/join)
/// - Zero-value share cleanup
/// - Balance conversion utils
module outcomes::share;

/// Raw balance for an outcome share
/// Contains the actual balance without the share object wrapper
public struct Balance has store {
    /// Amount of tokens for this outcome
    value: u64,
    /// ID of the market this share belongs to (prevents cross-market use)
    market_id: ID,
    /// Which outcome this share represents (0, 1, 2, etc.)
    outcome_index: u64,
}

/// A share representing a claim on a specific outcome in a prediction market
///
/// Shares have `key + store` abilities making them:
/// - Transferable via sui::transfer::public_transfer
/// - Storable in other objects
public struct Share has key, store {
    id: UID,
    /// The actual balance
    balance: Balance,
}

/// Error codes
const EInsufficientOutcomeValue: u64 = 0;
const EMarketOutcomeMismatch: u64 = 1;
const EShareNotZero: u64 = 2;

/// Create a new share (package-only, called by treasury)
///
/// # Arguments
/// * `market_id` - ID of the market this share belongs to
/// * `outcome_index` - Which outcome (0, 1, 2, etc.)
/// * `value` - Amount of tokens
/// * `ctx` - TxContext for creating new object
public(package) fun new(market_id: ID, outcome_index: u64, value: u64, ctx: &mut TxContext): Share {
    Share {
        id: object::new(ctx),
        balance: Balance { market_id, outcome_index, value },
    }
}

/// Destroy a share and return its components (package-only, called by treasury)
///
/// # Returns
/// * `market_id` - ID of the market
/// * `outcome_index` - Which outcome
/// * `value` - Amount of tokens that was in the share
public(package) fun destroy(share: Share): (ID, u64, u64) {
    let Share { id, balance } = share;
    let Balance { market_id, outcome_index, value } = balance;
    id.delete();

    (market_id, outcome_index, value)
}

/// Split a share into two shares
///
/// Removes `value` amount from the original share and creates a new share
/// with that amount. Both shares represent the same outcome in the same market.
///
/// # Arguments
/// * `share` - Share to split (modified in place)
/// * `value` - Amount to remove from original and put in new share
/// * `ctx` - TxContext for creating new share
///
/// # Aborts
/// * `EInsufficientOutcomeValue` - If share doesn't have enough tokens
public fun split(share: &mut Share, value: u64, ctx: &mut TxContext): Share {
    assert!(share.balance.value >= value, EInsufficientOutcomeValue);

    share.balance.value = share.balance.value - value;

    Share {
        id: object::new(ctx),
        balance: Balance {
            value: value,
            market_id: share.balance.market_id,
            outcome_index: share.balance.outcome_index,
        },
    }
}

/// Join two shares of the same market and outcome
///
/// Adds the value from `other` to `share` and destroys `other`.
/// Both shares must be for the same market and outcome.
///
/// # Arguments
/// * `share` - Share to add to (modified in place)
/// * `other` - Share to consume (destroyed)
///
/// # Aborts
/// * `EMarketOutcomeMismatch` - If shares are from different markets or outcomes
public fun join(share: &mut Share, other: Share) {
    let Share { id, balance } = other;
    let Balance { market_id, outcome_index, value } = balance;

    assert!(market_id == share.balance.market_id, EMarketOutcomeMismatch);
    assert!(outcome_index == share.balance.outcome_index, EMarketOutcomeMismatch);

    share.balance.value = share.balance.value + value;
    id.delete();
}

/// Join a share with a vector of other shares
///
/// Adds the value from each share in `others` to `share` and destroys them.
/// All shares must be for the same market and outcome.
///
/// # Arguments
/// * `share` - Share to add to (modified in place)
/// * `others` - Vector of shares to consume (destroyed)
///
///# Aborts
/// * `EMarketOutcomeMismatch` - If any shares are from different markets or outcomes
public fun join_vec(share: Share, others: vector<Share>): Share {
    others.fold!(share, |mut acc, other| {
        acc.join(other);
        acc
    })
}

/// Destroy a share that has zero value
///
/// Used for cleanup - removes empty shares from the system.
/// Share must have exactly 0 tokens.
///
/// # Arguments
/// * `share` - Share to destroy
///
/// # Aborts
/// * `EShareNotZero` - If share has non-zero value
public fun destroy_zero(share: Share) {
    let Share { id, balance } = share;
    let Balance { market_id: _, outcome_index: _, value } = balance;
    assert!(value == 0, EShareNotZero);

    id.delete();
}

/// Keep the share if non-zero, otherwise destroy it
///
/// Useful for cleaning up shares after operations that may result in zero-value shares.
/// # Arguments
/// * `share` - Share to keep or destroy
/// * `ctx` - TxContext for transferring if not destroyed
#[allow(lint(self_transfer))]
public fun keep_or_destroy_zero(share: Share, ctx: &mut TxContext) {
    if (share.value() == 0) {
        share.destroy_zero();
    } else {
        transfer::public_transfer(share, ctx.sender())
    }
}

/// Get the token amount in a share
public fun value(share: &Share): u64 {
    share.balance.value
}

/// Get which outcome this share represents (0, 1, 2, etc.)
public fun outcome_index(share: &Share): u64 {
    share.balance.outcome_index
}

/// Get the market ID this share belongs to
public fun market_id(share: &Share): ID {
    share.balance.market_id
}

/// Get the share's unique ID
public fun id(share: &Share): ID {
    share.id.to_inner()
}

/// Check if share has zero value
///
/// Useful before calling destroy_zero to avoid abort
public fun is_zero(share: &Share): bool {
    share.balance.value == 0
}

/// Check if share belongs to a specific market
///
/// # Arguments
/// * `share` - Share to check
/// * `market_id` - Market ID to verify against
///
/// # Returns
/// * `bool` - True if share belongs to this market
public fun belongs_to_market(share: &Share, market_id: ID): bool {
    share.balance.market_id == market_id
}

/// Convert a Share object to raw Balance
///
/// Destroys the Share wrapper and returns the underlying Balance.
/// Useful for storing balances in other structures.
///
/// # Arguments
/// * `share` - Share to convert
///
/// # Returns
/// * `Balance` - Raw balance
public fun into_balance(share: Share): Balance {
    let Share { id, balance } = share;
    id.delete();
    balance
}

/// Convert raw Balance to a Share object
///
/// Wraps a Balance in a new Share object with a fresh UID.
///
/// # Arguments
/// * `balance` - Raw balance
/// * `ctx` - TxContext for creating new object
///
/// # Returns
/// * `Share` - New share object
public fun from_balance(balance: Balance, ctx: &mut TxContext): Share {
    Share { id: object::new(ctx), balance }
}

#[test_only]
public fun create_for_testing(
    market_id: ID,
    outcome_index: u64,
    value: u64,
    ctx: &mut TxContext,
): Share {
    new(market_id, outcome_index, value, ctx)
}

#[test_only]
public fun destroy_for_testing(share: Share): u64 {
    let (_, _, value) = destroy(share);
    value
}
