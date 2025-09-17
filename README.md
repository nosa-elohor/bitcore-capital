# BitCore Capital Protocol

## 🧠 Overview

**BitCore Capital** is a decentralized Bitcoin-native lending platform built on **Stacks**, enabling users to unlock STX liquidity by collateralizing Bitcoin holdings—**without wrapping, intermediaries, or custodians**. It leverages the **Stacks Layer 2 Proof-of-Transfer (PoX)** consensus to inherit Bitcoin's unmatched proof-of-work security while supporting DeFi-native programmability.

The protocol introduces a **non-custodial**, **overcollateralized**, and **autonomously managed** lending marketplace for Bitcoiners to gain liquidity access without compromising long-term Bitcoin exposure.

---

## 🧱 System Architecture

**Key Layers:**

* **Bitcoin L1 (Security Layer):** Final settlement and cryptographic security via PoX.
* **Stacks L2 (Execution Layer):** Smart contract logic, asset management, and DeFi operations via Clarity.
* **BitCore Protocol (Application Layer):** Lending operations, liquidation logic, collateral tracking, and interest management.

```mermaid
graph TD
    A[Bitcoin Blockchain] -->|Proof of Transfer| B(Stacks Layer)
    B --> C[BitCore Capital Clarity Contracts]
    C --> D[Users (Bitcoin Holders)]
    C --> E[Oracles (BTC/STX Feeds)]
```

---

## 🧩 Smart Contract Architecture

The protocol is composed of **modular, permissioned, and secure Clarity contracts**, designed with an emphasis on **readability**, **auditability**, and **extensibility**.

### ✅ Core Modules

| Module                         | Responsibility                                           |
| ------------------------------ | -------------------------------------------------------- |
| `initialize-platform`          | One-time initialization (admin-only)                     |
| `request-loan`                 | Originate loans by locking BTC as collateral             |
| `repay-loan`                   | Repay loan + accrued interest, release collateral        |
| `check-liquidation`            | Autonomous monitoring for liquidation threshold breaches |
| `update-price-feed`            | Admin-only update to BTC oracle prices                   |
| `deposit-collateral`           | Explicit BTC collateral deposits (off-chain tracked)     |
| `update-collateral-ratio`      | Adjust protocol's collateralization policy               |
| `update-liquidation-threshold` | Adjust liquidation trigger point                         |

---

## 🔁 Data Flow

1. **Collateral Deposit**: Users lock BTC through an off-chain bridge or tracking mechanism, and register the amount via `deposit-collateral`.
2. **Loan Origination**: The user calls `request-loan`, which checks if the BTC collateral meets the minimum ratio based on live BTC/STX oracle feed.
3. **Interest Accrual**: Interest is computed via `calculate-interest`, based on elapsed blocks and fixed APR.
4. **Liquidation**: If the BTC price drops below the liquidation threshold, `check-liquidation` triggers `liquidate-position`.
5. **Repayment**: User repays with STX, interest is settled, BTC is unlocked.

---

## 📊 Data Structures

### 🔐 `loans` (Map)

Stores all loan metadata, including:

* `borrower`, `loan-amount`, `collateral-amount`
* `interest-rate`, `status`, `start-height`, `last-interest-calc`

### 👤 `user-loans` (Map)

Tracks each user's active loan IDs (max 10 per user).

### 💵 `collateral-prices` (Map)

Live price feeds for `BTC`, `STX`. Admin-maintained.

### 📈 Global Variables

* `total-btc-locked`: Total satoshis deposited as collateral.
* `total-loans-issued`: Running counter for loan ID assignments.
* `minimum-collateral-ratio`: Default `150%` overcollateralization.
* `liquidation-threshold`: Default `120%` trigger level.

---

## ⚙️ Deployment & Configuration

1. Deploy to a Stacks-compatible testnet/mainnet environment.
2. Call `initialize-platform` (admin-only).
3. Set initial BTC/STX oracle price via `update-price-feed`.
4. Adjust collateralization or liquidation thresholds if needed.

---

## 💼 Usage (Public Entry Points)

### Deposit Collateral

```clojure
(deposit-collateral amount)
```

Registers locked BTC (in satoshis). Requires off-chain custody proof.

---

### Request Loan

```clojure
(request-loan collateral loan-amount)
```

Issues STX loan if collateral meets required ratio. Returns `loan-id`.

---

### Repay Loan

```clojure
(repay-loan loan-id amount)
```

Repays principal + interest. Collateral is released upon full payment.

---

### Update Price Feed *(Admin Only)*

```clojure
(update-price-feed asset new-price)
```

Refreshes BTC/STX prices. Essential for accurate liquidation logic.

---

## 🔒 Security Considerations

* ✅ **Non-Custodial**: Users retain control of their BTC; protocol does not take custody.
* ✅ **Immutable Loan Tracking**: All loan data is transparent and auditable on-chain.
* ✅ **Oracle Integrity**: Price feeds are critical; use trusted oracles (e.g., Chainlink, Hiro) and consider multisig validation.
* ⚠️ **Off-Chain BTC Tracking**: Protocol assumes BTC deposits are honored via a watchtower or bridge mechanism. Use verifiable custody mechanisms.

---

## 📜 License & Acknowledgements

MIT License © BitCore Capital, 2025

Built with ❤️ on [Stacks](https://stacks.co), secured by Bitcoin.

Special thanks to:

* Clarity Lang maintainers
* Stacks Foundation
* Hiro Systems
