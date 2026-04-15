# Analysis of Entry Points, Whitelist & Operator Roles, and Deposit Flows

This document provides a comprehensive analysis of the access control mechanisms, role hierarchies,
and deposit/withdrawal flows for the protocol’s key integrations: **Direct Fleet Integration**,
**Rounds Integration**, and **Admirals Quarters (AQ) Integration**.  
It is intended for institutional stakeholders to understand how permissions are structured, how
whitelisting and operator roles are bound, and what configurations are required for each
integration.

---

## 1. Overview of Access Control & Roles

The protocol uses a central `ProtocolAccessManager` (V2 for newer components) to manage all roles.  
Key roles include:

| Role                                  | Identifier                                                    | Scope                                                                          | Managed By              |
| ------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------ | ----------------------- |
| **GOVERNOR_ROLE**                     | `keccak256("GOVERNOR_ROLE")`                                  | Global – can grant/revoke all other roles                                      | Self (initial governor) |
| **WHITELIST_MANAGER_ROLE**            | `keccak256("WHITELIST_MANAGER_ROLE")`                         | Global – can update the global whitelist (in ProtocolAccessManagerV2)          | GOVERNOR_ROLE           |
| **OPERATOR_ROLE** (contract-specific) | `generateRole(ContractSpecificRoles.OPERATOR_ROLE, contract)` | Per‑contract – bypasses gateway restrictions                                   | GOVERNOR_ROLE           |
| **KEEPER_ROLE** (contract-specific)   | `generateRole(ContractSpecificRoles.KEEPER_ROLE, contract)`   | Per‑contract – allowed to perform maintenance (e.g., `nextRound`, `rebalance`) | GOVERNOR_ROLE           |
| **SUPER_KEEPER_ROLE**                 | `keccak256("SUPER_KEEPER_ROLE")`                              | Global – can act as keeper for any contract                                    | GOVERNOR_ROLE           |
| **ADMIRALS_QUARTERS_ROLE**            | `keccak256("ADMIRALS_QUARTERS_ROLE")`                         | Global – allows the AQ bundler to withdraw on behalf of users                  | GOVERNOR_ROLE           |
| **GUARDIAN_ROLE**                     | `keccak256("GUARDIAN_ROLE")`                                  | Global – emergency pause/cancel powers (with expiration)                       | GOVERNOR_ROLE           |
| **FOUNDATION_ROLE**                   | `keccak256("FOUNDATION_ROLE")`                                | Global – vesting and treasury operations                                       | GOVERNOR_ROLE           |

**Whitelisting Mechanism (V2)**  
`ProtocolAccessManagerV2` introduces a global whitelist stored in `_whitelisted`.

- `isWhitelisted(context, account)` returns `true` if `address(0)` is whitelisted for the specific
  `context` (global open for that context) **or** the specific account is whitelisted for that
  context.
- Whitelist is managed by the `WHITELIST_MANAGER_ROLE`.

**Operator Role (V2)**  
`OPERATOR_ROLE` is contract‑specific.

- When granted for a specific fleet, the operator can call **deposit/mint/withdraw/redeem** and
  **transfer** shares even if the gateway is closed or the user is not whitelisted.
- This is used for internal protocol operations (e.g., Admirals Quarters moving funds).

---

## 2. Direct Fleet Integration (FleetCommanderWhitelist)

The `FleetCommanderWhitelist` contract is a 4626‑compliant vault that holds assets in a **buffer**
and allocates them to a set of **Arks**. It enforces entry/exit restrictions using a **gateway** and
the **whitelist**.

### 2.1 Required Role Setup

| Role                       | Target                           | Granted To                           | Purpose                                                        |
| -------------------------- | -------------------------------- | ------------------------------------ | -------------------------------------------------------------- |
| **WHITELIST_MANAGER_ROLE** | Access Manager                   | Governance / authorised addresses    | Manage global whitelist for this fleet.                        |
| **OPERATOR_ROLE**          | FleetCommanderWhitelist contract | Admirals Quarters / internal routers | Bypass gateway & whitelist for deposits/withdrawals/transfers. |
| **KEEPER_ROLE**            | FleetCommanderWhitelist contract | Keeper bots                          | Execute `rebalance` operations.                                |
| **SUPER_KEEPER_ROLE**      | Access Manager                   | (Optional) Emergency keepers         | Can rebalance any fleet if granted.                            |
| **GOVERNOR_ROLE**          | Access Manager                   | Multisig / governance                | Manage all roles, set configuration parameters.                |

**Note:** The fleet’s individual whitelists are stored in the central access manager, scoped by the
fleet address.
All deposit, mint, withdraw, redeem, and transfer operations are gated by `_enforceEntryGateway` /
`_enforceExitGateway`.

### 2.2 Deposit Flow

```plaintext
User / Operator
     │
     ▼
  deposit(assets, receiver)        // 1. Caller invokes deposit
     │
     ▼
  collectTip                        // 2. Accrue any pending performance fee
     │
     ▼
   _enforceEntryGateway(caller, receiver)
     ├─ if caller has OPERATOR_ROLE → allow (skip gateway)
     ├─ else if gateway closed → revert
     └─ else require caller & receiver whitelisted for this fleet (address(this))
     │
     ▼
  _validateDeposit(assets, caller) // 3. Check deposit cap & allowance
     │
     ▼
  _deposit(assets, shares)         // 4. Mint shares to receiver
     │
     ▼
  _board(bufferArk, assets)        // 5. Transfer assets to bufferArk
     │
     ▼
  emit FundsBufferBalanceUpdated
```

- **Operator bypass**: If caller has `OPERATOR_ROLE` for this fleet, deposit succeeds even if
  gateway is closed or caller/receiver are not whitelisted.
- **Standard users**: Must have gateway open (`config.isOperatorGatewayOpen == true`) **and** be
  whitelisted.

### 2.3 Withdraw / Redeem Flow (Buffer or Arks)

The contract first attempts to withdraw from the buffer (fast path); if insufficient, it withdraws
from arks in order of size.

```plaintext
User / Operator
     │
     ▼
  withdraw(assets, receiver, owner)  // or redeem(shares, receiver, owner)
     │
     ▼
  collectTip
     │
     ▼
   _enforceExitGateway(caller, receiver, owner)
     ├─ if caller has OPERATOR_ROLE → allow
     ├─ else if gateway closed → revert
     └─ else require caller, receiver, owner whitelisted for this fleet (address(this))
     │
     ▼
  if assets <= bufferBalance:
     │   → withdrawFromBuffer / redeemFromBuffer
     │       ├─ _validateBufferWithdraw / _validateBufferRedeem
     │       ├─ _disembark(bufferArk, amount)
     │       └─ _withdraw(...)
     │
     else:
     │   → withdrawFromArks / redeemFromArks
     │       ├─ _validateWithdrawFromArks / _validateRedeemFromArks
     │       ├─ _forceDisembarkFromSortedArks(amount)
     │       └─ _withdraw(...)
```

- **Operator** can withdraw/redeem even when gateway closed or participants not whitelisted.
- **Standard users** must have gateway open and all three participants whitelisted.

### 2.4 Transfer Flow (ERC20)

```solidity
function transfer(address to, uint256 amount) returns (bool) {
  if (hasOperatorRole(msg.sender)) {
    return super.transfer(to, amount);
  }
  require(transfersEnabled, 'FleetCommanderTransfersDisabled');
  require(isWhitelisted(address(this), msg.sender) && isWhitelisted(address(this), to), 'not whitelisted');
  return super.transfer(to, amount);
}
```

- **Operator** can transfer freely.
- **Other users** can transfer only if transfers are enabled **and** both sender and receiver are
  whitelisted.

---

## 3. Rounds Integration (RoundsVaultBase)

`RoundsVaultBase` is an abstract contract used for vaults that operate in discrete **rounds**. It
inherits `ProtocolAccessManagedV2` and uses its `Whitelist` adapter to delegate access checks to the
**contextual** `ProtocolAccessManagerV2` whitelist entries.

### 3.1 Required Role Setup

| Role                       | Target                   | Granted To              | Purpose                                                                                      |
| -------------------------- | ------------------------ | ----------------------- | -------------------------------------------------------------------------------------------- |
| **KEEPER_ROLE**            | RoundsVaultBase contract | Keeper bots             | Call `nextRound()` to advance rounds and `setRoundSettled()` to finalize settlement/trading. |
| **SUPER_KEEPER_ROLE**      | Access Manager           | (Optional)              | Can act as keeper for any rounds vault.                                                      |
| **GOVERNOR_ROLE**          | Access Manager           | Multisig / governance   | Manage roles and parameters.                                                                 |
| **WHITELIST_MANAGER_ROLE** | Access Manager           | Governance / authorized | Manage the contextual whitelists that this vault depends on.                                 |

**Important:** Unlike the `FleetCommander`, the `RoundsVaultBase` **does not** implement an
`OPERATOR_ROLE` bypass for its deposit/redeem functions. This means that:

- The **Admirals Quarters (AQ)** contract address **MUST** be whitelisted for the specific
  **Rounds Vault** being used (the `vault()` context).
- Failure to whitelist AQ for the specific vault context will cause all bundled
  deposits/redemptions to revert even if the user is whitelisted.
- This applies to both the caller and the receiver of the assets.

### 3.2 Deposit Flow

```plaintext
User / Admirals Quarters
  │
  ▼
deposit(assets, receiver)   // 1. Caller deposits assets
  │
  ▼
onlyWhitelisted(vault(), receiver) && onlyWhitelisted(vault(), caller)
  │
  ▼
super.deposit(assets, receiver)   // 2. Mint ERC1155 receipt for current round
  │
  ▼
Underlying assets are held in the contract until nextRound()
```

- Deposits are only allowed **during an open round** (`RoundState.Opened`).
- **Whitelisting is mandatory**: Both caller and receiver must be whitelisted for the vault.

### 3.3 Redemption Flow (Immediate – Current Round)

```plaintext
User / Admirals Quarters
  │
  ▼
redeem(id, amount, receiver, owner)   // id must equal current round
  │
  ▼
onlyWhitelisted(vault(), owner, receiver, caller)
  │
  ▼
_burn(owner, id, amount)              // Burn receipt
  │
  ▼
transfer underlying asset to receiver (immediate)
```

- **Whitelisting is mandatory** for all participants (caller, owner, receiver).

### 3.4 Exchange Asset Redemption (Settled Rounds)

After a round is **settled** (by keeper calling `setRoundSettled`), users can redeem their receipts
for the **exchange asset** (shares of the target vault or the underlying asset, depending on vault
type).

```plaintext
User / Admirals Quarters
  │
  ▼
redeemExchangeAsset(id, amount, receiver, owner)
  │
  ▼
require(id < currentRound && roundState[id] == Settled)
  │
  ▼
onlyWhitelisted(vault(), owner, receiver, caller)
  │
  ▼
_burn(owner, id, amount)              // Burn receipt
  │
  ▼
exchangeAmount = exchangeRateByRound[id].quote(amount)
  │
  ▼
safeTransfer(exchangeAsset, receiver, exchangeAmount)
```

- **Whitelisting is mandatory** for all participants.

### 3.5 Round Lifecycle (Two-Phase Settlement)

The protocol uses a two-phase mechanism to decouple round advancement from the actual trade
execution and settlement. This allows the vault to accurately capture off-chain reality (NAV drift)
during settlement.

#### Phase 1: Advance Round (Keeper)

This phase closes the current round to new deposits and opens a new one immediately. No funds are
moved yet.

```plaintext
Keeper
  │
  ▼
nextRound()
  │
  ▼
roundState[currentRound] = InSettlement
  │
  ▼
_roundNumber++
  │
  ▼
roundState[newRound] = Opened
```

#### Phase 2: Settle Round (Keeper)

This phase executes the actual fund movement (`_operate`) for a round that is `InSettlement`. Once
complete, it finalizes the exchange rate and marks the round as `Settled`.

```plaintext
Keeper
  │
  ▼
setRoundSettled(roundId)
  │
  ▼
require(roundState[roundId] == InSettlement)
  │
  ▼
frozenAmount = totalSupply(roundId)
  │
  ▼
_operate(frozenAmount)  // Executes trade (e.g., move funds to/from target vault)
  │
  ▼
Price finalRate = (outputAmount > 0)
  ? toPrice(outputAmount, frozenAmount)
  : _getFallbackExchangeRate()
  │
  ▼
_exchangeRateByRound[roundId] = finalRate
  │
  ▼
roundState[roundId] = Settled
```

- After **Phase 1**, the vault is ready for new deposits in the next round index.
- After **Phase 2**, users can call `redeemExchangeAsset` for the settled round.

---

## 4. Admirals Quarters (AQ) Integration

The **Admirals Quarters** is a bundler contract that allows users to unstake and withdraw assets
from fleets and vaults.

### 4.1 Required Role Setup

| Role                       | Target               | Granted To          | Purpose                                                                   |
| -------------------------- | -------------------- | ------------------- | ------------------------------------------------------------------------- |
| **ADMIRALS_QUARTERS_ROLE** | Access Manager       | AQ contract address | Allows AQ to perform privileged operations globally.                      |
| **OPERATOR_ROLE**          | Each Target Contract | AQ contract address | **Fleet Only**: Bypasses gateway and whitelist restrictions.              |
| **WHITELISTED**            | Specific Vault Context | AQ contract address | **Rounds Vaults**: Mandatory for AQ to deposit/redeem on behalf of users. |

### 4.2 Protected Multicall (Bundling)

> [!IMPORTANT]
> The `multicall` function itself is **not** gated by a central whitelist. Instead, it serves as a 
> relay that allows multiple operations to be batched safely.

- **Security Model**: Access control is enforced at the **destination function** level 
  (e.g., inside `enterFleet`).
- **Context Awareness**: `AdmiralsQuartersWhitelist` ensures that when calling sensitive functions 
  like `enterFleet`, the user is whitelisted for the *specific fleet* they are about to join.

### 4.3 Integration Differences: Fleets vs Rounds

| Feature                   | FleetCommanderWhitelist           | RoundsVaultBase                    |
| ------------------------- | --------------------------------- | ---------------------------------- |
| **Operator Bypass**       | Supported (via `hasOperatorRole`) | **Not Supported**                  |
| **Whitelist Requirement** | Bypassed if caller is an operator | **Mandatory for all callers**      |
| **AQ Role Requirement**   | Re-checks roles internally        | Relies on whitelist for entry/exit |
| **Whitelist Context**     | Fleet Address                     | Vault Address                      |

**Note for AQ Developers**: When integrating with a `RoundsVault`, the AQ contract address **must be
manually whitelisted for the specific vault context**, otherwise all `deposit` and
`redeem` calls will revert with `NotWhitelisted(VAULT_ADDRESS, AQ_ADDRESS)`.

---

## 5. Summary of Entry Points and Role Dependencies

| Integration           | Entry Points                                            | Whitelist Source | Operator Role Needed     | Whitelist Bypass?              |
| --------------------- | ------------------------------------------------------- | ---------------- | ------------------------ | ------------------------------ |
| **Fleet (Whitelist)** | `deposit`, `mint`, `withdraw`, `redeem`, `transfer`     | Global           | Yes (for bypass)         | **Yes**, for operators         |
| **Rounds**            | `deposit`, `redeem`, `redeemExchangeAsset`, `nextRound` | Global           | No (not used for bypass) | **No**, whitelisting mandatory |
| **Admirals Quarters** | Calls to target functions                               | Global           | Yes (for Fleets)         | Depends on target              |

---

## 6. Configuration Steps for Each Integration

### 6.1 Direct Fleet Integration

1. **Deploy `ProtocolAccessManagerV2`** with an initial governor.
2. **Grant `WHITELIST_MANAGER_ROLE`** to authorized addresses.
3. **Deploy `FleetCommanderWhitelist`** pointing to the access manager.
4. **Grant `OPERATOR_ROLE`** to the AQ contract for this fleet.
5. **Set configuration** via governor (caps, gateway, etc.).

### 6.2 Rounds Integration

1. **Deploy `ProtocolAccessManagerV2`** (or reuse).
2. **Deploy a rounds vault** pointing to the access manager.
3. **Grant `KEEPER_ROLE`** to the rounds keeper.
4. **Whitelisting**: Ensure all users **and the AQ contract** (if used) are added to the global
   whitelist via the `WHITELIST_MANAGER`.
5. **Initial State**: Round 0 is initialized as `Opened` by default. Settlement must be called for
   each round after it is advanced.

### 6.3 Admirals Quarters Integration

1. **Grant `ADMIRALS_QUARTERS_ROLE`** to the AQ contract.
2. **For Fleets**: Grant `OPERATOR_ROLE` to AQ for the specific fleet.
3. **For Rounds**: Add the AQ address to the **global whitelist**.

---

## 7. Security Considerations

- **Governor role** is highly privileged; it should be held by a multisig or DAO.
- **Whitelist manager** can grant entry to the system; for institutional fleets, this is a critical
  gate.
- **Admirals Quarters** bypasses fleet whitelists via the operator role, but must itself be
  whitelisted for Rounds Vaults. This "double lock" for Rounds adds an extra layer of visibility for
  institutional vaults.
- **Keeper role** for rounds must be trusted to advance the system state correctly.

---

## 8. Appendix: Role Derivation in Code

- **Contract‑specific roles** are generated as:
  ```solidity
  keccak256(abi.encodePacked(roleName, roleTargetContract))
  ```
- **OPERATOR_ROLE** for a fleet:  
  `keccak256(abi.encodePacked(ContractSpecificRoles.OPERATOR_ROLE, fleetAddress))`

All role checks in the contract use `_accessManager.hasRole(role, account)` (for global roles) or
`_accessManager.hasRole(generateRole(...), account)` (for contract‑specific roles).

---

This document accurately reflects the current state of the protocol where `RoundsVaultBase` enforces
global whitelisting without an operator bypass, requiring even bundled services like Admirals
Quarters to be whitelisted for interaction.
