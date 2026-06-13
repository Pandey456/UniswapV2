# UniswapV2 — Building an AMM from scratch

Building a Uniswap V2–style AMM in Solidity + Foundry. This is a learning project — I'm working through the V2 architecture by implementing it from first principles, one contract at a time.

**Status:** Design done. Coding starts now.

---

## Build roadmap

Built in phases. Each phase ships independently before moving to the next.

- [x] **Phase 0 — ERC-20 tokens** (deployed to Sepolia)
      Token A and Token B as the base pair.
      → [Pandey456/ERC-20_Token](https://github.com/Pandey456/ERC-20_Token)
- [ ] **Phase 1 — Pool contract** (current focus)
      The actual AMM. One pool, two tokens. `addLiquidity`, `removeLiquidity`, `swap`.
- [ ] **Phase 2 — Factory contract**
      Deploys new Pools, prevents duplicates, maintains a registry of all pairs.
- [ ] **Phase 3 — Router contract**
      Multi-hop swaps and the user-convenience layer (slippage tolerance, deadlines, ratio matching).
**Status:** Phase 1 in progress. Pool + LP Token written; test suite ~50% done.
Not building all three at once on purpose. The Pool is the hard part; the Factory and Router are orchestration layers that only make sense once a working Pool exists.

---

## Architecture

V2's three-contract design:

```
            User wallet
                 |
                 v
        +-----------------+
        |     Router      |   user-facing convenience layer
        +--------+--------+
                 |
                 |  asks: "where's the pool for token0/token1?"
                 v
        +-----------------+
        |     Factory     |   registry + deploys new Pools
        +--------+--------+
                 |
                 |  returns pool address (or creates one)
                 v
        +-----------------+
        |  Pool (the AMM) |   holds reserves, executes swaps,
        |   x · y = k     |   mints/burns LP tokens
        +-----------------+
```

Three contracts, three jobs:

### Pool
Where everything actually happens. Holds reserves of two tokens, enforces `x · y = k`, and mints LP tokens when liquidity is added (burns them on withdrawal). The Pool *is* the ERC-20 contract for its own LP token.

Three functions:
- `addLiquidity` — deposit both tokens, get LP tokens back
- `removeLiquidity` — burn LP tokens, get a proportional slice of the reserves
- `swap` — trade one token for the other

### Factory
Just a registry + deployer. Two responsibilities:
- Deploy new Pool contracts (one per token pair) using `CREATE2` so addresses are deterministic from the token pair
- Maintain `getPool[tokenA][tokenB] → poolAddress` so anyone can look up the canonical Pool

The Factory doesn't handle liquidity or swaps directly — it's only consulted to find a pool or create one.

### Router
User-facing, stateless, holds no assets. Handles:
- Single and multi-hop swaps (A → B → C across multiple pools)
- Slippage protection and deadline checks
- Calculating optimal deposit ratios so LPs don't accidentally donate to existing LPs
- Looking up pool addresses via the Factory

Multi-hop isn't anything fancy — the Router just calls `swap()` on multiple Pools in sequence, feeding the output of one into the next.

---

## The math

The whole AMM has exactly four formulas. Everything else is bookkeeping.

### Constant product invariant
```
x · y = k
```
- `x` = reserve of token0
- `y` = reserve of token1
- `k` = the product, which must never decrease (and grows slightly with each fee-bearing swap)

### LP token minting

**First liquidity provider** (pool is empty):
```
shares = sqrt(Δx · Δy)
```
Geometric mean of the two deposits. This is what makes per-share value scale linearly with pool size.

**Subsequent liquidity providers:**
```
shares = min(
    (Δx · totalSupply) / reserveX,
    (Δy · totalSupply) / reserveY
)
```
The `min(...)` matters. If you deposit off-ratio, the excess on the bigger side gets no share credit — it effectively donates to existing LPs. Forces honest ratio matching.

### Swap output

Without fee:
```
Δy = (y · Δx) / (x + Δx)
```

With 0.3% LP fee (V2 form, integer math):
```
Δy = (y · Δx · 997) / (x · 1000 + Δx · 997)
```

The 0.3% fee stays in the pool. It grows `k`, which is how LPs earn from trading volume — silently, into the reserves.

### Liquidity removal (proportional)
```
amount0 = (shares · reserve0) / totalSupply
amount1 = (shares · reserve1) / totalSupply
```
Burn the user's LP shares, send them their proportional slice of each reserve. No price involved — just shares-to-reserves arithmetic.

### Slippage protection

Every swap takes a `minAmountOut` parameter. The function checks:
```
require(Δy >= minAmountOut)
```
If the executed output is less than what the user demanded — e.g., because of MEV / front-running between signing and execution — the whole transaction reverts. User pays gas but keeps their input tokens.

---

## Security considerations

Attacks I'm thinking about and how I plan to handle each:

| Attack | Defense |
|---|---|
| **Reentrancy** on swap and removeLiquidity | CEI pattern: checks → effects (state changes) → interactions (token transfers). All state updates happen before any external call. |
| **First-LP inflation attack** | Plan: V2-style `MINIMUM_LIQUIDITY = 1000` permanently locked on first deposit. Final decision pending — see Open Questions. |
| **Donation attacks** (raw token transfers to the pool) | V2 has `sync()` / `skim()` to reconcile. Likely deferred to a later phase. |
| **Integer division precision** | Always multiply before dividing. `(a * b) / c` — never `(a / c) * b`. |
| **Fee-on-transfer tokens** | Not supported in v1. Documented as a known limitation. |
| **Slippage / sandwich attacks** | `minAmountOut` on every swap. |

I'll run Slither on each phase before deploying anything to mainnet.

---

## Open questions

Things I haven't fully decided yet — open for revisiting as I build:

- **MINIMUM_LIQUIDITY lock** — implement in v1 (2 extra lines, blocks a real attack class), or skip for now and document?
- **Fee model** — hard-code 0.3%, or configurable per pool? Leaning fixed for v1.
- **Token ordering** — sort by address (V2-style) in the Factory, or accept whatever order the deployer passes? Probably accept for v1, sort starting from v2.
- **LP token naming** — per-pair like V2's `UNI-V2`, or a single generic symbol?
- **TWAP oracle** — out of scope for v1. Worth considering for v2.

---

## Local development

```bash
# Build
forge build

# Test (once tests exist)
forge test

# Static analysis
slither .

# Local fork
anvil
```

---

## Deployed contracts

**Phase 0 — ERC-20 tokens (Sepolia)**

| Asset | Address |
|---|---|
| Token A | [`0xf64c5955...50d6d1d`](https://sepolia.etherscan.io/address/0xf64c595579fde59a8a26c502bf492de9650d6d1d) |
| Token B | [`0xa9d479f9...b35fb156`](https://sepolia.etherscan.io/address/0xa9d479f9685660b02a32b44c768aa6e1b35fb156) |

Phase 1+ — coming soon.

---

## Why this project

I want to become a smart-contract / protocol engineer. Reading V2's source is hard until you've built one yourself, so I'm working through the architecture by implementing it from scratch. Building in public — find me on X: [@pandeyy456](https://x.com/pandeyy456).

Loosely following the Cyfrin Updraft track but writing every contract myself instead of following tutorials. The point is the wrestling, not the typing.
