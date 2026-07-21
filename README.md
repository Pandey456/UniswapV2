# UniswapV2 — Building an AMM from scratch

Building a Uniswap V2–style AMM in Solidity + Foundry. This is a learning project — I'm working through the V2 architecture by implementing it from first principles, one contract at a time.

---

**Status:** v1 complete. Live on Sepolia. Three contracts deployed and verified, wired to a working frontend.

## 🔥 Try it live

**[swap.adarshpandey.xyz](https://swap.adarshpandey.xyz)** — connect a wallet on Sepolia testnet and:

- Create a new liquidity pool for any token pair
- Add or remove liquidity
- Swap tokens (single-hop and multi-hop)

Frontend built with **viem** + wagmi + RainbowKit. Talks directly to the deployed contracts — no backend, no proxy. All routing logic lives in the Router contract.

_Coming soon:_ same URL will point to a low-gas EVM L2 deployment (Base / Polygon / Arbitrum — decision pending). Sepolia stays available for testing.

---

## Build roadmap

- [x] **Phase 0 — ERC-20 tokens** (Sepolia)
      Token A and Token B as the base pair for the AMM.
      → [Pandey456/ERC-20_Token](https://github.com/Pandey456/ERC-20_Token)
- [x] **Phase 1 — Pool contract**
      The AMM core. Inherits ERC20 (LP token IS the Pool). Balance-check pattern for token verification. MINIMUM_LIQUIDITY lock. ReentrancyGuard on all external functions.
- [x] **Phase 2 — Factory contract**
      Deploys new Pools via CREATE2 with the initialize pattern — addresses are computable off-chain without touching the chain.
- [x] **Phase 3 — Router contract**
      User-facing convenience layer. Multi-hop swaps, optimal ratio matching for addLiquidity, slippage protection, deadline checks. Pre-pushes tokens to pools (V2-style optimistic transfers).
- [x] **Phase 4 — Frontend** ([swap.adarshpandey.xyz](https://swap.adarshpandey.xyz))
      viem + wagmi + Vite. Direct contract interaction, no server layer.
- [x] **Phase 5 — L2 mainnet deployment**
      Redeploy to a Polygon. Same frontend URL will re-point to mainnet addresses; Sepolia stays as a testing environment.

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
             |  computes pool address off-chain via CREATE2 formula
             v
    +-----------------+
    |     Factory     |   deploys new Pools, registers them
    +--------+--------+
             |
             |  returns pool address (or creates one)
             v
    +-----------------+
    |  Pool (the AMM) |   holds reserves, executes swaps,
    |   x · y = k     |   IS the LP token (inherits ERC20)
    +-----------------+
```

Three contracts, three jobs:

### Pool

Where everything actually happens. Holds reserves of two tokens, enforces `x · y = k`, mints LP tokens on liquidity add. **The Pool contract itself IS the ERC-20 LP token** — no separate LP contract to keep in sync.

Uses the **balance-check pattern**: doesn't trust caller-provided amounts. Reads `balanceOf(this)` to detect what actually arrived. Router pre-pushes tokens before calling swap/addLiquidity; Pool verifies the arrival.

Three functions:

- `addLiquidity` — deposit both tokens, get LP tokens back
- `removeLiquidity` — burn LP tokens, get proportional reserves back
- `swap` — trade one token for the other

### Factory

Deploys new Pools using **CREATE2 with the initialize pattern**:

- Pool has a zero-argument constructor, so its `creationCode` is constant
- Factory deploys via `new pool{salt: keccak256(token0, token1)}()`
- Then calls `pool.initialize(token0, token1)` to set the tokens

Result: pool addresses are derivable purely from the token pair, off-chain. Router uses this to skip Factory lookups on every swap.

Bidirectional registration in `poolRegistry[tokenA][tokenB]` so lookups work in either order.

### Router

User-facing, stateless, holds no assets. Handles:

- Single-hop and multi-hop swaps
- Ratio matching for `addLiquidity` — if user provides off-ratio amounts, Router computes the optimal subset that matches current pool reserves
- Slippage protection at the aggregate output level
- Deadline enforcement
- **Off-chain pool address computation** — Router caches Pool's bytecode hash at construction and derives pool addresses via the CREATE2 formula, no on-chain lookups per swap

Multi-hop pattern: for a path `[A, B, C]`, Router pre-pushes A to the A/B pool, executes swap A→B with output going directly to the B/C pool, then executes swap B→C with output going to the user. Tokens flow through pools without touching Router's balance.

---

## The math

Four formulas. Everything else is bookkeeping.

### Constant product invariant

```
x · y = k
```

- `x` = reserve of token0
- `y` = reserve of token1
- `k` = the product, which must never decrease (grows slightly with each fee-bearing swap — that's how LPs earn)

### LP token minting

**First liquidity provider** (pool is empty):

```
shares = sqrt(Δx · Δy) - MINIMUM_LIQUIDITY
```

Geometric mean of the two deposits, minus 1000 tokens permanently locked at `address(1)` to prevent the first-LP inflation attack.

**Subsequent liquidity providers:**

```
shares = min(
(Δx · totalSupply) / reserveX,
(Δy · totalSupply) / reserveY
)
```

The `min(...)` forces honest ratio matching. Off-ratio excess donates to existing LPs.

### Swap output

With 0.3% LP fee (V2 form, integer math):

```
Δy = (y · Δx · 997) / (x · 1000 + Δx · 997)
```

The 0.3% fee stays in the pool. It grows `k`, silently increasing per-share value.

### Liquidity removal (proportional)

```
amount0 = (shares · reserve0) / totalSupply
amount1 = (shares · reserve1) / totalSupply
```

Burn shares, send proportional slice of each reserve.

### Slippage protection

Every swap takes `minAmountOut`. Router asserts final output ≥ threshold after all hops. Intermediate hops don't check slippage — only the aggregate matters.

---

## Design decisions worth noting

Choices made during implementation that diverge from a straight V2 clone:

**Pool inherits ERC20 directly.** No separate LPToken contract. Simpler CREATE2 (smaller init code), lower gas (no external call for mint/burn), no state sync between two contracts.

**Initialize pattern instead of constructor args.** Pool constructor takes zero args; Factory calls `initialize(token0, token1)` right after deployment. This keeps `type(pool).creationCode` stable across all pools, which is what lets Router compute pool addresses off-chain without knowing per-pool constructor args.

**Balance-check (optimistic transfer) pattern.** Pool doesn't do `transferFrom` internally. Callers pre-push tokens to Pool's address, then invoke swap/addLiquidity. Pool verifies via `balanceOf(this) - recordedReserve >= claimedAmount`. Fewer external calls, matches V2's production design.

**Router caches pool bytecode hash.** At Router deployment, `poolHash = keccak256(type(pool).creationCode)` gets stored as immutable. Every subsequent `getExpectedAddr()` call is pure math — no chain reads to find pools.

---

## Security considerations

Attacks defended against and how:

| Attack                                      | Defense                                                                                  | Status              |
| ------------------------------------------- | ---------------------------------------------------------------------------------------- | ------------------- |
| Reentrancy on all external functions        | `ReentrancyGuard.nonReentrant` on Pool.addLiquidity / swap / removeLiquidity             | ✅ Implemented      |
| First-LP inflation attack                   | `MINIMUM_LIQUIDITY = 1000` permanently minted to `address(1)` on first liquidity         | ✅ Implemented      |
| Direct Pool exploitation (bypassing Router) | Balance-check pattern — Pool verifies token arrival via `balanceOf`                      | ✅ Implemented      |
| Integer division precision                  | Multiply before divide, throughout                                                       | ✅ Enforced         |
| Slippage / sandwich attacks                 | `minAmountOut` on swap; aggregated at Router level for multi-hop                         | ✅ Implemented      |
| Duplicate pool creation                     | Factory checks `poolRegistry` before deploying; blocks duplicates                        | ✅ Implemented      |
| Initialize front-running                    | `initialize` gated by `msg.sender == i_FactoryAddress` and one-shot `isInitialized` flag | ✅ Implemented      |
| Fee-on-transfer tokens                      | Not supported                                                                            | ⚠️ Known limitation |
| Donation attacks (raw transfers)            | No `sync()`/`skim()`; donations become dust                                              | ⚠️ Known limitation |

Static analysis: Slither runs clean on Pool + Factory (naming convention warnings only).

---

## Deployed contracts

### Current — Sepolia testnet (v1 live)

| Contract     | Address                                      |
| ------------ | -------------------------------------------- |
| Factory      | `0xae1cf56E2Df39E4EE9203DcEd781C75799E36202` |
| Router       | `0x1163318B8A7a3c1454e4a6D7103646C91948E0ce` |
| Test Token A | `0xa9d479f9685660b02a32b44c768aa6e1b35fb156` |
| Test Token B | `0xf64c595579fde59a8a26c502bf492de9650d6d1d` |

Pool contracts are deployed on demand by the Factory. Each pair gets its own Pool at a deterministic CREATE2 address — computable off-chain from the pair.

All contracts verified on Sepolia Etherscan.

### Planned — L2 mainnet (v1.1)

Deploying to a low-gas EVM L2 next. Candidate chains: **Base**, **Polygon**, **Arbitrum** — final choice pending on ecosystem fit and testing depth. When live, [swap.adarshpandey.xyz](https://swap.adarshpandey.xyz) will re-point to the mainnet contracts; Sepolia stays available as a testing environment.

---

## Frontend

Live at **[swap.adarshpandey.xyz](https://swap.adarshpandey.xyz)**.

Stack:

- **viem** for chain interaction (typed ABIs, no ethers.js)
- **wagmi** for React hooks
- **RainbowKit** for wallet connection
- **Vite + React** for the app shell
- Deployed on Netlify

Three tabs: Swap, Add Liquidity, Remove Liquidity. Wallet connects directly to Sepolia. No backend, no relay layer — the browser talks straight to the contracts.

---

## Local development

```bash
# Build
forge build

# Test
forge test

# Coverage
forge coverage

# Static analysis
slither .

# Local fork of Sepolia
anvil --fork-url $SEPOLIA_RPC_URL
```

---

## Why this project

I want to become a smart-contract / protocol engineer. Reading V2's source is hard until you've built one yourself, so I'm working through the architecture by implementing it from scratch. Building in public — find me on X: [@pandeyy456](https://x.com/pandeyy456).

Loosely following the Cyfrin Updraft track but writing every contract myself instead of following tutorials. The point is the wrestling, not the typing.
