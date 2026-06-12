
# Uniswap V2 Protocol Specification

This document serves as the comprehensive design and architectural plan for building a decentralized automated market maker (AMM) based on the Uniswap V2 core architecture.

---

## 1. System Architecture Diagram

```
                 +-------------------+
                 |    User Wallet    |
                 +---------+---------+
                           |
            1. Interact with Router Contract
                           v
                 +-------------------+
                 |      Router       |
                 +----+---------+----+
                      |         |
     2a. Add Liquidity|         | 2b. Query / Execute Swap
    (If Pool missing) |         |     (Single or Multi-hop)
                      v         v
                 +----+---------+----+
                 |      Factory      |
                 +----+---------+----+
                      |         |
       3a. Create Pool|         | 3b. Fetch Pool Address
                      v         v
                 +----+---------+----+
                 |    Pool (Pair)    |
                 +-------------------+
                 | - x * y = k       |
                 | - Mint/Burn LP    |
                 | - Swap Engine     |
                 +-------------------+
```

---

## 2. Core Contracts Architecture

The protocol is split into three main contracts to maintain clear separation of concerns, optimize gas, and maximize security.

### 2.1 Router
The **Router** is the primary peripheral contract. It serves as the main entry point for user interactions. It is stateless and does not hold ecosystem assets.

* **Routing Decisions:** Dynamically evaluates inbound user calls to distinguish between liquidity management and asset swapping.
* **Liquidity Management Delegation:** When a user triggers an asset provisioning workflow, the Router checks the registry and routes configuration parameters to the **Factory**.
* **Swap Routing & Path Optimization:** When an asset exchange is requested, the Router queries the Factory registry to determine pool availability. It calculates whether the exchange can occur via a **Single Swap** (direct pair pool) or a **Multi-hop Swap** (routing through intermediary liquidity pools, e.g., Token A $\rightarrow$ Token B $\rightarrow$ Token C).

### 2.2 Factory
The **Factory** acts as the protocol registry and the deployment ledger for all initialized pair pools.

* **Pool Existence Verification:** When receiving an asset provisioning request from the Router, it determines whether a dedicated contract for the requested pair already exists.
* **Dynamic Pair Deployment:**
    * If the pair pool **exists**, it forwards the liquidity provision instruction.
    * If the pair pool **does not exist**, it programmatically deploys a new instance of the **Pool** contract using deterministic address generation (`CREATE2`) and registers the mapping directory within its global storage array.

### 2.3 Pool (The Pair Contract)
The **Pool** contract is the core execution environment. It acts as an ERC-20 token contract itself (representing Liquidity Provider ownership shares) and directly holds the reserves of the two underlying assets. It implements three primary functions:

1.  `addLiquidity`
2.  `swap`
3.  `removeLiquidity`

---

## 3. Core Mathematical Mechanics & Formulae

### 3.1 Constant Product Invariant (`addLiquidity`)
The liquidity pool operates on the constant product market maker formulation:

$$x \cdot y = k$$

Where:
* $x$ = Reserve balance of Token 0
* $y$ = Reserve balance of Token 1
* $k$ = The invariant value that must remain constant or increase during execution cycles.

#### LP Token Minting Mechanics
When liquidity is added, Liquidity Provider (LP) tokens are minted to track a user's relative ownership share of the underlying pool reserves. These tokens are standard ERC-20 assets with full `mint`, `burn`, and `transfer` functionality.

* **Initial Bootstrapping (First Liquidity Event):**
    To establish the initial pool exchange rate, the first deposit mints LP tokens equivalent to the geometric mean of the underlying deposit quantities:
    $$\text{Qty}_{\text{LP}} = \sqrt{\Delta x \cdot \Delta y}$$

* **Subsequent Liquidity Provisions:**
    To preserve price parity and prevent dilution, subsequent minting operations scale linearly with the pool's existing total supply. The amount minted is bounded by the lesser relative share provided:
    $$\text{Qty}_{\text{LP}} = \min\left( \frac{\Delta x \cdot \text{Total}_{\text{LP}}}{x}, \frac{\Delta y \cdot \text{Total}_{\text{LP}}}{y} \right)$$

---

### 3.2 Automated Asset Swap (`swap`)
The swap engine handles the single-sided deposition of one asset and calculates the precise maximum extractable volume of the counterpart asset.

#### Execution Formula
Based on the constant product rule ($x \cdot y = (x + \Delta x)(y - \Delta y)$), the fraction of assets transferred out to the recipient wallet ($\Delta y$) is determined dynamically by tracking the inbound delta ($\Delta x$):

$$\Delta y = \frac{y \cdot \Delta x}{x + \Delta x}$$

Where:
* $\Delta x$ = The net inbound token quantity injected into the pool by the user (calculated as $\text{Gross Input} - \text{Protocol Fee}$).
* $x$ = Current active pool reserve of the inbound asset.
* $y$ = Current active pool reserve of the outbound asset.
* $\Delta y$ = The total output token quantity to be transferred to the user's wallet.

#### Slippage Protection Engine
Due to concurrent state modifications on public ledgers, an execution threshold must be enforced to guard against high price impacts and frontrunning:
* The transaction includes a strict user-defined variable: `minAmt`.
* The execution engine asserts: $\Delta y \geq \text{minAmt}$.
* If the calculated output amount ($\Delta y$) drops below `minAmt` due to adverse price slippage during block inclusion, the state modifications are rolled back and the transaction reverts.

---

### 3.3 Liquidity Extraction (`removeLiquidity`)
Any account holding LP tokens can redeem their ownership shares for their underlying fractional assets. Executing this call deposits the specified LP tokens back to the Pool contract to be burned.

The quantities of Token 0 and Token 1 returned to the user are calculated proportionally using the following equations:

$$\text{Amount}_0 = \frac{\text{Share}_{\text{LP}} \cdot x}{\text{Total}_{\text{LP}}}$$

$$\text{Amount}_1 = \frac{\text{Share}_{\text{LP}} \cdot y}{\text{Total}_{\text{LP}}}$$

Where:
* $\text{Share}_{\text{LP}}$ = The quantity of LP tokens submitted by the user to be burned.
* $\text{Total}_{\text{LP}}$ = The total outstanding circulating supply of the pool's LP tokens.
* $x$ = Total reserve quantity of Token 0 currently held in the pool.
* $y$ = Total reserve quantity of Token 1 currently held in the pool.
* $\text{Amount}_0$ / $\text{Amount}_1$ = The exact quantities of the respective tokens transferred to the user's wallet.
