# Deep Context: Rounds Vault -> Fleet Commander -> WT/Maple Arks

## 1. Phase 1 — Initial Orientation (Bottom-Up Scan)

### System Architecture
The system allows users to asynchronously enter and exit complex off-chain/institutional yields (WisdomTree, Maple) without exposing the protocol to NAV-strike sandwich attacks or settlement failures.

- **RoundsVaultBase (Input/Output)**: Accumulates user deposits over time. On round transition, moves the aggregate capital to/from the target vault. Issues ERC1155 receipts mapped to specific rounds.
- **FleetCommanderWhitelist**: The "Target Vault" of the Rounds Vaults. It is an fully compliant ERC4626 vault that allocates its aggregated capital into underlying yield-generating "Arks".
- **WisdomTreeArk**: Interfaces with off-chain WT funds. Because WT operates with T+0 or T+1 physical settlement and a daily NAV strike (after 4PM), the Ark uses `pendingDepositAssets` and `pendingWithdrawalAssets` to shield its `totalAssets()` from fluctuations while capital is in transit.
- **MapleInstitutionalArk**: Interfaces with Maple's Syrup pools. Deposits are synchronous, but withdrawals require an asynchronous withdrawal request mechanism.

---

## 2. Phase 2 — Ultra-Granular Function Analysis

### 2.1 `WisdomTreeArk.totalAssets()` & `_board()`
- **Purpose**: Triggers a deposit of USDC to the off-chain entity and continuously tracks the live value of the Ark while gracefully handling asynchronous off-chain settlements without allowing the total assets to drop artificially.
- **Inputs & Assumptions**: 
  - Relies on Chainlink `oracle`, `cachedShareBalance`, and `pendingDepositAssets`.
  - Assumes WT will honor the deposit 1:1 in USDC equivalent shares.
- **Block-by-Block Analysis**:
  - `if (isArkFrozen) return _frozenTotalAssets;`
    - *Why here*: Ex-dividend defense. Prevents the total assets from dropping on the ex-div date (when share NAV drips) before the DRIP T+1 dividend shares arrive.
  - `uint256 currentShares = pendingDepositAssets > 0 ? cachedShareBalance : shareToken.balanceOf(address(assetsForwarder));`
    - *What it does*: Locks in the share balance exactly as it was when the deposit started.
    - *Why here*: If deposits are in-flight to WT, WT might mint T0/T1 shares before the Keeper runs `clearPendingDeposit()`. If we used the live `balanceOf`, we would double-count the newly minted shares PLUS the `pendingDepositAssets` USDC value. Using `cachedShareBalance` strictly isolates the pre-deposit share value.
  - `assets = _sharesToAssets(currentShares) + pendingWithdrawalAssets + pendingDepositAssets;`
    - *Why here*: Unifies the 3 states of WT capital (Settled Shares, In-flight Redemptions, In-flight Subscriptions).
- **First Principles**: The Ark must continuously report an accurate NAV. Off-chain capital transitions phase from USD -> (WT Custodian) -> Shares. By accounting for `pendingDepositAssets` linearly (1:1 USD) while freezing the physical share count, the Ark's `totalAssets()` avoids a double-counting shock.
- **Invariants**:
  - When `pendingDepositAssets > 0`, `currentShares` == `cachedShareBalance`.

### 2.2 `WisdomTreeArk.clearPendingDeposit(uint256 amount)`
- **Purpose**: Moves the Ark state from "Async Settlement" back to "Live Recognition" after WT physical shares arrive in the `assetsForwarder`.
- **Inputs & Assumptions**:
  - Keeper calls this ONLY after verifying shares actually arrived.
  - Decrements `pendingDepositAssets`.
- **Outputs & Effects**:
  - If `pendingDepositAssets` goes to 0, `totalAssets()` resumes using the live `shareToken.balanceOf()`.
  - The newly arrived shares are now recognized, and their value is multiplied by the new Oracle NAV.
- **Risk Considerations (5 Whys/Hazards)**:
  - *Why must Keeper do this after physical arrival?* If Keeper calls to clear before shares arrive, `currentShares` switches to live balance (which is missing the shares). `totalAssets()` will instantly gap down by the `amount` of the pending deposit.
  - *Why is T+1 NAV strike important?* WT updates the Oracle NAV after 4 PM. If the Keeper clears deposits BEFORE the NAV updates, the shares will be mispriced at yesterday's NAV.
  - *Flow Hazard*: Erroneous clearing sequence causes temporary NAV shocks, exposing the Fleet to sandwich arbitrage.

### 2.3 `RoundsVaultBase.nextRound()`
- **Purpose**: Progresses the batched user deposits into the next logical state and executes the bulk operation against the Fleet Commander.
- **Inputs & Assumptions**: `onlyKeeper`. Assumes `_operate()` correctly moves the capital into/out of the target vault.
- **Block-by-Block analysis**:
  - `Price memory exchangeRate = _getCurrentExchangeRate();`
    - *What*: Captures the current ratio of Vault Shares to Underlying synchronously.
  - `_exchangeRateByRound[_roundNumber] = exchangeRate;`
    - *Why here*: Locks in the exact NAV at the moment the round closes. Asynchronous changes later do not affect Round N's exchange rate.
  - `roundState[_roundNumber] = RoundState.InSettlement;`
    - *What*: Changes state to prevent immediate user exits.
  - `_operate();`
    - *What*: For Input Vault, this deposits USDC into Fleet Commander. For Output Vault, it requests redemption from Fleet Commander.
- **Cross-Function Dependency Risk**:
  - **The Timing Attack**: The Keeper MUST call `nextRound()` on the `RoundsVault` ONLY when the underlying Arks (e.g. WisdomTree) are in a settled, non-frozen state. If `nextRound()` is called while WisdomTree is in an Ex-Div frozen state (`isArkFrozen`), the exchange rate captured might be artificial.

### 2.4 `RoundsVaultBase._redeemExchangeAsset(...)`
- **Purpose**: Allows users to exchange their historical Round N receipts for the exact Target Vault Shares (Input) or USDC (Output) they earned, AFTER async settlement completes.
- **Block-by-Block analysis**:
  - `if (roundState[id] != RoundState.Settled) revert RoundNotSettled(id);`
    - *Why here*: Enforces the async boundary. Users wait here for the Keeper to resolve T+1 nav / Maple queue latency.
  - `_burn(owner, id, amount);`
    - *What*: Check-Effects-Interactions (CEI) to prevent reentrancy before the asset transfer.
  - `exchangeAmount = _exchangeRateByRound[id].quote(amount);`
    - *What*: Calculates exact pro-rata output using the snapshot recorded during `nextRound()`.

---

## 3. Phase 3 — Global System Understanding & Workflows

### 3.1 The Complete WisdomTree Subscription Workflow
1. **User (T-1)**: Enters `RoundsVaultInput` with USDC. Receives Round N ERC1155 receipt.
2. **Keeper (T0, Pre-4PM)**: Calls `nextRound()` on Rounds Vault.
   - Rounds Vault locks `exchangeRate` and changes state to `InSettlement`.
   - Deposits aggregated USDC into Fleet Commander.
   - Fleet Commander allocates USDC (via `board`) into `WisdomTreeArk`.
   - `WisdomTreeArk._board` snapshots `cachedShareBalance`, increments `pendingDepositAssets`, sends USDC to WT.
3. **WT System (T0, Post-4PM)**:
   - NAV is struck by physical fund operators.
   - Chainlink Oracle is updated.
   - Shares are minted and sent to Ark's off-chain custodian, then transferred to `assetsForwarder`.
4. **Keeper (T1)**:
   - Verifies shares physically arrived.
   - Calls `WisdomTreeArk.clearPendingDeposit()`. Ark NAV recognition is now complete, ending the async phase.
   - Calls `RoundsVaultBase.setRoundSettled(N)`. Round N async settlement is formally closed.
5. **User (T1+)**: Exchanges Round N receipt for their slice of the Fleet Commander shares.

### 3.2 Identified Fragility Clusters & Implicit Trust Boundaries
1. **Keeper Operational Ordering (CRITICAL)**:
   - The Keeper is the ultimate synchronizer of reality between Off-Chain (WT/Maple) and On-Chain.
   - **Hazard A (Premature Clearance)**: Clearing `WisdomTreeArk.pendingDepositAssets` before WT physical shares arrive causes a devastating temporary drop in Fleet `totalAssets()`, breaking ERC4626 equivalence logic momentarily.
   - **Hazard B (Premature Round Execution)**: Calling `RoundsVault.nextRound()` while an underlying Ark is waiting for NAV updates or while shares are un-cleared means the `_getCurrentExchangeRate()` snapshot captured for Round N users will be based on stale or artificially frozen (`_frozenTotalAssets`) data.
2. **The Output Vault Sweep Constraint**:
   - During redemptions for Output Vaults, `RoundsVaultOutput.nextRound()` redeems Fleet Shares -> Fleet requests WT withdrawals -> WT shares sent away, `pendingWithdrawalAssets` increments.
   - **Assumption**: `pendingWithdrawalAssets` accurately reflects the *exact* USDC value that WT will wire back upon physical settlement. 
   - When the wire arrives, Keeper calls `sweep()`. If WT wires slightly less due to off-chain fees or slippage, `sweep()` has a `sweetSlippage` verification check. If strict slippage fails, `sweep()` reverts, permanently stalling the Fleet pipeline and leaving Rounds Vault N indefinitely `InSettlement`.
3. **Maple Withdrawal Queue Latency**:
   - `MapleInstitutionalArk.requestWithdrawal` places the sequence in an asynchronous Maple queue.
   - The Fleet and Rounds Vault rely fully on Keeper omniscience to recognize when `ISyrupWithdrawalManagerV2` has actually released the funds before moving the RoundsVault state to settled.

### 3.3 Complexity Heatmap
- `WisdomTreeArk.totalAssets()` is the most sensitive calculation in the framework due to the dual-state overlay (`isArkFrozen` vs `cachedShareBalance`).
- The `RoundsVaultBase` cleanly isolates the protocol from real-time deposit/withdrawal sandwich attacks but entirely delegates the timing safety to the Keeper operational layer.
