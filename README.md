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
- `supply::create<T: drop>(witness: T, market: &UID, num_outcomes: u64): (SupplyState<T>, SupplyCap<T>)`
- `supply::mint<T>(cap: &SupplyCap<T>, state: &mut SupplyState<T>, outcome_index: u64, value: u64, ctx: &mut TxContext): Share<T>`
- `supply::mint_vec<T>(cap: &SupplyCap<T>, state: &mut SupplyState<T>, value: u64, ctx: &mut TxContext): vector<Share<T>>` (one per outcome index, empty if `num_outcomes == 0`)
- `supply::burn<T>(cap: &SupplyCap<T>, state: &mut SupplyState<T>, share: Share<T>): u64`
- `supply::burn_vec<T>(cap: &SupplyCap<T>, state: &mut SupplyState<T>, shares: vector<Share<T>>)` (burns provided shares; caller enforces shape)

### Share  
- `share::split<T>(share: &mut Share<T>, amount: u64, ctx: &mut TxContext): Share<T>`
- `share::join<T>(share: &mut Share<T>, other: Share<T>)`
- `share::destroy_zero<T>(share: Share<T>)`
- `share::keep_or_destroy_zero<T>(share: Share<T>)`
- `share::into_balance<T>(share: Share<T>): Balance<T>`
- `share::from_balance<T>(balance: Balance<T>, ctx: &mut TxContext): Share<T>`

### Getters

**Share getters:**
- `share::value<T>(share: &Share<T>): u64`
- `share::outcome_index<T>(share: &Share<T>): u64`
- `share::market_id<T>(share: &Share<T>): ID`
- `share::id<T>(share: &Share<T>): ID`
- `share::is_zero<T>(share: &Share<T>): bool`
- `share::belongs_to_market<T>(share: &Share<T>, market_id: ID): bool`

**Supply State getters:**
- `supply::total_supply<T>(state: &SupplyState<T>, outcome_index: u64): u64`
- `supply::supply_values<T>(state: &SupplyState<T>): vector<u64>`
- `supply::num_outcomes<T>(state: &SupplyState<T>): u64`
- `supply::market_id<T>(state: &SupplyState<T>): ID`
- `supply::id<T>(state: &SupplyState<T>): ID`

**Supply State Capability getters:**
- `supply::supply_state_id<T>(cap: &SupplyCap<T>): ID`
- `supply::cap_id<T>(cap: &SupplyCap<T>): ID`
- `supply::is_state_cap<T>(cap: &SupplyCap<T>, state: &SupplyState<T>): bool`

## Design Decisions

- **No outcome names** - just indices (0, 1, 2...). Markets map to names (YES/NO, Trump/Biden)
- **No complete sets** - markets implement their own mint/burn economics
- **No collateral handling** - token standard doesn't touch collateral
- **Minimal core** - markets add features on top

## Security

1. **Type ownership** via witness pattern - outcomes can be tied to a platform
2. **Market binding** via UID reference
3. **Capability control** via SupplyCap
4. **Overflow protection** in minting and burning

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
