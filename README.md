# Outcome Tokens for Sui

A standard for prediction markets outcomes on Sui. Inspired by Gnosis Conditional Tokens but designed for Sui's object model.

## Why

- Sui's `Coin` or balance `Supply` standard requires deploying new packages per market (impractical)
- Need outcome differentiation (YES/NO shares)
- Need market isolation (prevent cross-market contamination)
- Enable DeFi composability (use shares as collateral, in Lending, in AMMs, etc)

## Features

- **Witness-based supply state creation** - only market module can mint
- **Market isolation** - shares tied to specific markets via UID
- **Share operations** - split, join, destroy_zero
- **Supply tracking** - monitor minted/burned per outcome
- **DeFi ready** - `key + store` for wallets, kiosks, transfers

## Quick Start

```move
module my_market::prediction {
    struct PredictionPlatform() has drop;
    
    public fun create(ctx: &mut TxContext) {
        let market_uid = object::new(ctx);

        let (supply_state, cap) = supply::create(
            PredictionPlatform(),
            &market_uid,
            2, // outcomes (YES/NO), (UP/DOWN), etc
            ctx
        );

        // Store supply state and capability in your market object
    }
}
```

## Core API

### Supply State
- `supply::create(market: &mut UID, num_outcomes: u64): (SupplyState, SupplyCap)`
- `supply::mint(cap: &SupplyCap, state: &mut SupplyState, outcome_index: u64, value: u64, ctx: &mut TxContext): Share`
- `supply::mint_vec(cap: &SupplyCap, state: &mut SupplyState, value: u64, ctx: &mut TxContext): vector<Share>` (one per outcome index, empty if `num_outcomes == 0`)
- `supply::burn(cap: &SupplyCap, state: &mut SupplyState, share: Share): u64`
- `supply::burn_vec(cap: &SupplyCap, state: &mut SupplyState, shares: vector<Share>)` (burns provided shares; caller enforces shape)

### Share  
- `share::split(share: &mut Share, amount: u64, ctx: &mut TxContext): Share`
- `share::join(share: &mut Share, other: Share)`
- `share::destroy_zero(share: Share)`
- `share::keep_or_destroy_zero(share: Share)`
- `share::into_balance(share: Share): Balance`
- `share::from_balance(balance: Balance, ctx: &mut TxContext): Share`

### Getters

**Share getters:**
- `share::value(share: &Share): u64`
- `share::outcome_index(share: &Share): u64`
- `share::market_id(share: &Share): ID`
- `share::id(share: &Share): ID`
- `share::is_zero(share: &Share): bool`
- `share::belongs_to_market(share: &Share, market_id: ID): bool`

**Supply State getters:**
- `supply::total_supply(state: &SupplyState, outcome_index: u64): u64`
- `supply::supply_values(state: &SupplyState): vector<u64>`
- `supply::num_outcomes(state: &SupplyState): u64`
- `supply::market_id(state: &SupplyState): ID`
- `supply::id(state: &SupplyState): ID`

**Supply State Capability getters:**
- `supply::supply_state_id(cap: &SupplyCap): ID`
- `supply::cap_id(cap: &SupplyCap): ID`
- `supply::is_state_cap(cap: &SupplyCap, state: &SupplyState): bool`

## Design Decisions

- **No outcome names** - just indices (0, 1, 2...). Markets map to names (YES/NO, Trump/Biden)
- **No complete sets** - markets implement their own mint/burn economics
- **No collateral handling** - token standard doesn't touch collateral
- **Minimal core** - markets add features on top

## Security

1. **Market binding** via UID reference
2. **Capability control** via SupplyCap
3. **Overflow protection** in minting and burning

## vs Alternatives

**vs Sui Coin or balance Supply**
- No deployment per market
- Outcome differentiation  
- Shared infrastructure

**vs Custom Tokens**
- Standardized interface
- Security patterns
- Instant composability

## DeFi Composability

Standardized shares enable:
- **Transfer and trading** - `key + store` abilities for wallets and explorers
- **AMM liquidity** - Trade shares against tokens or other shares  
- **Marketplace integration** - List on NFT marketplaces via kiosks

One integration supports ALL markets.

## Coming Soon

- **Conditional tokens** - markets that depend on other market outcomes
- **Batch operations** - mint/burn multiple shares efficiently
- **Flash share loans** - borrow shares within a transaction

## License

MIT
