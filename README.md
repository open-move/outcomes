# Outcome Tokens for Sui

A standard for prediction markets outcomes on Sui. Inspired by Gnosis Conditional Tokens but designed for Sui's object model.

## Why

- Sui's `Coin` or balance `Supply` standard requires deploying new packages per market (impractical)
- Need outcome differentiation (YES/NO positions)
- Need market isolation (prevent cross-market contamination)
- Enable DeFi composability (use positions as collateral, in Lending, in AMMs, etc)

## Features

- **Witness-based supply manager creation** - only market module can mint
- **Market isolation** - positions tied to specific markets via UID
- **Position operations** - split, join, destroy_zero
- **Supply tracking** - monitor minted/burned per outcome
- **DeFi ready** - `key + store` for wallets, kiosks, transfers

## Quick Start

```move
module my_market::prediction {
    struct PredictionPlatform() has drop;
    
    public fun create(ctx: &mut TxContext) {
        let market_uid = object::new(ctx);

        let (supply_manager, cap) = supply::create(
            PredictionPlatform(),
            &market_uid,
            2, // outcomes (YES/NO), (UP/DOWN), etc
            ctx
        );

        // Store supply manager and capability in your market object
    }
}
```

## Core API

### Supply Manager
- `supply::create<T: drop>(witness: T, market: &UID, num_outcomes: u64, ctx: &mut TxContext): (SupplyManager<T>, SupplyManagerCap<T>)`
- `supply::mint<T>(cap: &SupplyManagerCap<T>, manager: &mut SupplyManager<T>, outcome_index: u64, value: u64, ctx: &mut TxContext): Position<T>`
- `supply::burn<T>(cap: &SupplyManagerCap<T>, manager: &mut SupplyManager<T>, position: Position<T>): u64`

### Position  
- `position::split<T>(position: &mut Position<T>, amount: u64, ctx: &mut TxContext): Position<T>`
- `position::join<T>(position: &mut Position<T>, other: Position<T>)`
- `position::destroy_zero<T>(position: Position<T>)`
- `position::into_balance<T>(position: Position<T>): Balance<T>`
- `position::from_balance<T>(balance: Balance<T>, ctx: &mut TxContext): Position<T>`

### Getters

**Position getters:**
- `position::value<T>(position: &Position<T>): u64`
- `position::outcome_index<T>(position: &Position<T>): u64`
- `position::market_id<T>(position: &Position<T>): ID`
- `position::id<T>(position: &Position<T>): ID`
- `position::is_zero<T>(position: &Position<T>): bool`
- `position::belongs_to_market<T>(position: &Position<T>, market_id: ID): bool`

**Supply Manager getters:**
- `supply::total_supply<T>(manager: &SupplyManager<T>, outcome_index: u64): u64`
- `supply::supply_values<T>(manager: &SupplyManager<T>): vector<u64>`
- `supply::num_outcomes<T>(manager: &SupplyManager<T>): u64`
- `supply::market_id<T>(manager: &SupplyManager<T>): ID`
- `supply::id<T>(manager: &SupplyManager<T>): ID`

**Supply Manager Capability getters:**
- `supply::supply_manager_id<T>(cap: &SupplyManagerCap<T>): ID`
- `supply::cap_id<T>(cap: &SupplyManagerCap<T>): ID`
- `supply::is_manager_cap<T>(cap: &SupplyManagerCap<T>, manager: &SupplyManager<T>): bool`

## Design Decisions

- **No outcome names** - just indices (0, 1, 2...). Markets map to names (YES/NO, Trump/Biden)
- **No complete sets** - markets implement their own mint/burn economics
- **No collateral handling** - token standard doesn't touch collateral
- **Minimal core** - markets add features on top

## Security

1. **Type ownership** via witness pattern - outcomes can be tied to a platform
2. **Market binding** via UID reference
3. **Capability control** via SupplyManagerCap
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

Standardized positions enable:
- **Transfer and trading** - `key + store` abilities for wallets and explorers
- **AMM liquidity** - Trade positions against tokens or other positions  
- **Marketplace integration** - List on NFT marketplaces via kiosks

One integration supports ALL markets.

## Coming Soon

- **Conditional tokens** - markets that depend on other market outcomes
- **Batch operations** - mint/burn multiple positions efficiently
- **Flash position loans** - borrow positions within a transaction

## License

MIT