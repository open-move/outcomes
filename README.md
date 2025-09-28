# Outcome Tokens for Sui

A standard for prediction markets outcomes on Sui. Inspired by Gnosis Conditional Tokens but designed for Sui's object model.

## Why

- Sui's `Coin` or balance `Supply` standard requires deploying new packages per market (impractical)
- Need outcome differentiation (YES/NO positions)
- Need market isolation (prevent cross-market contamination)
- Enable DeFi composability (use positions as collateral, in Lending, in AMMs, etc)

## Features

- **Witness-based treasury creation** - only market module can mint
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

        let treasury = outcomes::create_treasury(
            PredictionPlatform(),
            &market_uid,
            2, // outcomes (YES/NO), (UP/DOWN), etc
            ctx
        );

        // Store treasury in your market object
    }
}
```

## Core API

### Treasury
- `outcomes::create_treasury<T: drop>(witness: T, market: &UID, num_outcomes: u64, ctx: &mut TxContext): TreasuryCap<T>`
- `outcomes::mint<T>(treasury: &mut TreasuryCap<T>, outcome_index: u64, value: u64, ctx: &mut TxContext): Position<T>`
- `outcomes::burn<T>(treasury: &mut TreasuryCap<T>, position: Position<T>): u64`

### Position  
- `outcomes::split<T>(position: &mut Position<T>, amount: u64, ctx: &mut TxContext): Position<T>`
- `outcomes::join<T>(position: &mut Position<T>, other: Position<T>)`
- `outcomes::destroy_zero<T>(position: Position<T>)`
- `outcomes::into_balance<T>(position: Position<T>): Balance<T>`
- `outcomes::from_balance<T>(balance: Balance<T>, ctx: &mut TxContext): Position<T>`

### Getters
- `outcomes::value<T>(position: &Position<T>): u64`
- `outcomes::outcome_index<T>(position: &Position<T>): u64`
- `outcomes::market_id<T>(position: &Position<T>): ID`
- `outcomes::total_supply<T>(treasury: &TreasuryCap<T>, outcome_index: u64): u64`

## Design Decisions

- **No outcome names** - just indices (0, 1, 2...). Markets map to names (YES/NO, Trump/Biden)
- **No complete sets** - markets implement their own mint/burn economics
- **No collateral handling** - token standard doesn't touch collateral
- **Minimal core** - markets add features on top

## Security

1. **Type ownership** via witness pattern - outcomes can be tied to a platform
2. **Market binding** via UID reference
3. **Capability control** via TreasuryCap
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