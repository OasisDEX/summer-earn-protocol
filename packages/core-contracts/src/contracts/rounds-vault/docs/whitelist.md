# Analysis of Entry Points, Whitelist & Operator Roles, and Deposit Flows

This document provides a comprehensive analysis of the access control mechanisms, role hierarchies, and deposit/withdrawal flows for the protocol’s key integrations: **Direct Fleet Integration**, **Rounds Integration**, and **Admirals Quarters (AQ) Integration**.  
It is intended for institutional stakeholders to understand how permissions are structured, how whitelisting and operator roles are bound, and what configurations are required for each integration.

---

## 1. Overview of Access Control & Roles

The protocol uses a central `ProtocolAccessManager` (V2 for newer components) to manage all roles.  
Key roles include:

| Role | Identifier | Scope | Managed By |
|------|------------|-------|------------|
| **GOVERNOR_ROLE** | `keccak256("GOVERNOR_ROLE")` | Global – can grant/revoke all other roles | Self (initial governor) |
| **WHITELIST_MANAGER_ROLE** | `keccak256("WHITELIST_MANAGER_ROLE")` | Global – can update the global whitelist (in ProtocolAccessManagerV2) | GOVERNOR_ROLE |
| **OPERATOR_ROLE** (contract-specific) | `generateRole(ContractSpecificRoles.OPERATOR_ROLE, contract)` | Per‑contract – bypasses gateway restrictions | GOVERNOR_ROLE |
| **KEEPER_ROLE** (contract-specific) | `generateRole(ContractSpecificRoles.KEEPER_ROLE, contract)` | Per‑contract – allowed to perform maintenance (e.g., `nextRound`, `rebalance`) | GOVERNOR_ROLE |
| **SUPER_KEEPER_ROLE** | `keccak256("SUPER_KEEPER_ROLE")` | Global – can act as keeper for any contract | GOVERNOR_ROLE |
| **ADMIRALS_QUARTERS_ROLE** | `keccak256("ADMIRALS_QUARTERS_ROLE")` | Global – allows the AQ bundler to withdraw on behalf of users | GOVERNOR_ROLE |
| **GUARDIAN_ROLE** | `keccak256("GUARDIAN_ROLE")` | Global – emergency pause/cancel powers (with expiration) | GOVERNOR_ROLE |
| **FOUNDATION_ROLE** | `keccak256("FOUNDATION_ROLE")` | Global – vesting and treasury operations | GOVERNOR_ROLE |

**Whitelisting Mechanism (V2)**  
`ProtocolAccessManagerV2` introduces a global whitelist stored in `_whitelisted`.  
- `isWhitelisted(account)` returns `true` if `address(0)` is whitelisted (global open) **or** the specific account is whitelisted.  
- Whitelist is managed by the `WHITELIST_MANAGER_ROLE`.

**Operator Role (V2)**  
`OPERATOR_ROLE` is contract‑specific.  
- When granted for a specific fleet, the operator can call **deposit/mint/withdraw/redeem** and **transfer** shares even if the gateway is closed or the user is not whitelisted.  
- This is used for internal protocol operations (e.g., Admirals Quarters moving funds).

---

## 2. Direct Fleet Integration (FleetCommanderWhitelist)

The `FleetCommanderWhitelist` contract is a 4626‑compliant vault that holds assets in a **buffer** and allocates them to a set of **Arks**. It enforces entry/exit restrictions using a **gateway** and the **whitelist**.

### 2.1 Required Role Setup

| Role | Target | Granted To | Purpose |
|------|--------|------------|---------|
| **WHITELIST_MANAGER_ROLE** | Access Manager | Governance / authorised addresses | Manage global whitelist for this fleet. |
| **OPERATOR_ROLE** | FleetCommanderWhitelist contract | Admirals Quarters / internal routers | Bypass gateway & whitelist for deposits/withdrawals/transfers. |
| **KEEPER_ROLE** | FleetCommanderWhitelist contract | Keeper bots | Execute `rebalance` operations. |
| **SUPER_KEEPER_ROLE** | Access Manager | (Optional) Emergency keepers | Can rebalance any fleet if granted. |
| **GOVERNOR_ROLE** | Access Manager | Multisig / governance | Manage all roles, set configuration parameters. |

**Note:** The fleet’s own whitelist **is the global whitelist** stored in the access manager.  
All deposit, mint, withdraw, redeem, and transfer operations are gated by `_enforceEntryGateway` / `_enforceExitGateway`.

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
     └─ else require caller & receiver whitelisted
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

- **Operator bypass**: If caller has `OPERATOR_ROLE` for this fleet, deposit succeeds even if gateway is closed or caller/receiver are not whitelisted.  
- **Standard users**: Must have gateway open (`config.isOperatorGatewayOpen == true`) **and** be whitelisted.

### 2.3 Withdraw / Redeem Flow (Buffer or Arks)

The contract first attempts to withdraw from the buffer (fast path); if insufficient, it withdraws from arks in order of size.

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
     └─ else require caller, receiver, owner whitelisted
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
    require(transfersEnabled, "FleetCommanderTransfersDisabled");
    require(isWhitelisted(msg.sender) && isWhitelisted(to), "not whitelisted");
    return super.transfer(to, amount);
}
```

- **Operator** can transfer freely.  
- **Other users** can transfer only if transfers are enabled **and** both sender and receiver are whitelisted.

---

## 3. Rounds Integration (RoundsVaultBase)

`RoundsVaultBase` is an abstract contract used for vaults that operate in discrete **rounds**. It inherits `ProtocolAccessManagedV2` (so it expects the access manager to support V2) and uses its **own** whitelist (separate from the fleet whitelist) to gate deposits and redemptions.

### 3.1 Required Role Setup

| Role | Target | Granted To | Purpose |
|------|--------|------------|---------|
| **KEEPER_ROLE** | RoundsVaultBase contract | Keeper bots | Call `nextRound()` and `setRoundSettled()` to advance rounds and finalise settlement. |
| **SUPER_KEEPER_ROLE** | Access Manager | (Optional) | Can act as keeper for any rounds vault. |
| **GOVERNOR_ROLE** | Access Manager | Multisig / governance | Manage whitelist (via `setWhitelisted`), grant other roles. |

**Important:** The whitelist used here is **not** the global access manager whitelist.  
`RoundsVaultBase` includes its own `Whitelist` contract that stores `_whitelisted` mapping and uses `onlyGovernor` to manage it.  
The `onlyWhitelisted` modifier checks this local whitelist.

### 3.2 Deposit Flow

```plaintext
User
  │
  ▼
deposit(assets, receiver)   // 1. Caller deposits assets
  │
  ▼
onlyWhitelisted(receiver) && onlyWhitelisted(caller)   // 2. Both must be whitelisted
  │
  ▼
super.deposit(assets, receiver)   // 3. Mint ERC1155 receipt for current round
  │
  ▼
Underlying assets are held in the contract until nextRound()
```

- Deposits are only allowed **during an open round** (`RoundState.Opened`).  
- Receipts are minted as ERC‑1155 tokens (ID = current round number).  
- After `nextRound()` is called, the current round is closed and a new round begins.

### 3.3 Redemption Flow (Immediate – Current Round)

```plaintext
User
  │
  ▼
redeem(id, amount, receiver, owner)   // id must equal current round
  │
  ▼
onlyWhitelisted(owner, receiver, caller)
  │
  ▼
_burn(owner, id, amount)              // Burn receipt
  │
  ▼
transfer underlying asset to receiver (immediate)
```

- Redeem only possible for the **current round** (receipts for previous rounds must use `redeemExchangeAsset`).

### 3.4 Exchange Asset Redemption (Settled Rounds)

After a round is **settled** (by keeper calling `setRoundSettled`), users can redeem their receipts for the **exchange asset** (shares of the target vault or the underlying asset, depending on vault type).

```plaintext
User
  │
  ▼
redeemExchangeAsset(id, amount, receiver, owner)
  │
  ▼
require(id < currentRound && roundState[id] == Settled)
  │
  ▼
onlyWhitelisted(owner, receiver, caller)
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

- Exchange rate is captured at the end of each round (`_getCurrentExchangeRate()` in `nextRound`).  
- This allows users to claim the value of their investment after the round has been processed by the target vault.

### 3.5 Round Transition (Keeper)

```plaintext
Keeper
  │
  ▼
nextRound()
  │
  ▼
Price exchangeRate = _getCurrentExchangeRate()
  │
  ▼
_exchangeRateByRound[currentRound] = exchangeRate
  │
  ▼
roundState[currentRound] = InSettlement
  │
  ▼
_operate()   // Overridden by derived contract – moves funds to/from target vault
  │
  ▼
_roundNumber++
  │
  ▼
roundState[newRound] = Opened
```

- After the new round is opened, deposits can start again.  
- Keeper must later call `setRoundSettled(prevRound)` after settlement operations are complete.

---

## 4. Admirals Quarters (AQ) Integration

The **Admirals Quarters** is a bundler contract that allows users to unstake and withdraw assets from fleets **directly to their wallet**, reducing risk of manipulation. It relies on two roles:

- **ADMIRALS_QUARTERS_ROLE** – global role assigned to the AQ contract itself.  
- **OPERATOR_ROLE** (contract‑specific) – assigned to the AQ contract for each fleet it interacts with, to bypass gateway/whitelist restrictions.

### 4.1 Required Role Setup

| Role | Target | Granted To | Purpose |
|------|--------|------------|---------|
| **ADMIRALS_QUARTERS_ROLE** | Access Manager | AQ contract address | Allows AQ to perform its core operations (e.g., `unstakeAndWithdraw`). |
| **OPERATOR_ROLE** | Each FleetCommanderWhitelist | AQ contract address | Bypass gateway/whitelist when calling `withdraw`/`redeem` on behalf of users. |
| **GOVERNOR_ROLE** | Access Manager | Multisig / governance | Grant the above roles. |

### 4.2 Typical Flow (User → AQ → Fleet)

```plaintext
User
  │ 1. Approve AQ to spend shares (if required)
  │
  ▼
AQ.unstakeAndWithdraw(fleetAddress, shares, user)
  │
  ▼
AQ (has ADMIRALS_QUARTERS_ROLE) calls fleet.withdraw(redeem) with parameters:
   - caller = AQ
   - receiver = user
   - owner = user (or AQ if shares were transferred)
  │
  ▼
FleetCommanderWhitelist._enforceExitGateway(caller, receiver, owner)
  ├─ AQ has OPERATOR_ROLE → allowed
  └─ proceeds with withdrawal
  │
  ▼
Fleet withdraws assets directly to user's wallet
```

- Because AQ is **operator**, it bypasses all gateway and whitelist checks.  
- Withdrawn assets go directly to the user (as specified by `receiver`), preventing the AQ contract from holding user funds.  
- The `ADMIRALS_QUARTERS_ROLE` is used in other parts of the protocol (e.g., in `hasAdmiralsQuartersRole`) to gate specific functions that should only be callable by the AQ bundler.

---

## 5. Summary of Entry Points and Role Dependencies

| Integration | Entry Points | Whitelist Source | Operator Role Needed | Other Roles |
|-------------|--------------|------------------|----------------------|-------------|
| **Fleet (Whitelist)** | `deposit`, `mint`, `withdraw`, `redeem`, `transfer` | Global (Access Manager V2) | Yes – to bypass gateway/whitelist | `KEEPER_ROLE` for rebalancing |
| **Rounds** | `deposit`, `redeem`, `redeemExchangeAsset`, `nextRound` | Local (Vault’s own Whitelist) | No – but `KEEPER_ROLE` needed for round transitions | `SUPER_KEEPER_ROLE` optional |
| **Admirals Quarters** | Calls to fleet functions (e.g., `withdraw`) | Global | Yes – for fleet interactions | `ADMIRALS_QUARTERS_ROLE` for AQ‑specific functions |

---

## 6. Configuration Steps for Each Integration

### 6.1 Direct Fleet Integration

1. **Deploy `ProtocolAccessManagerV2`** with an initial governor (e.g., a multisig).  
2. **Grant `WHITELIST_MANAGER_ROLE`** to addresses that will manage the global whitelist.  
3. **Deploy `FleetCommanderWhitelist`** with the access manager address.  
4. **Grant `OPERATOR_ROLE`** to any external contracts (e.g., AQ) that need to move funds without restrictions.  
5. **Grant `KEEPER_ROLE`** to bots that will call `rebalance`.  
6. **Use the whitelist manager** to set `address(0)` (global open) or specific accounts.  
7. **Set configuration** via governor: deposit caps, ark parameters, gateway status, transferability, etc.

### 6.2 Rounds Integration

1. **Deploy `ProtocolAccessManagerV2`** (or reuse existing).  
2. **Deploy a rounds vault** (e.g., `InputRoundsVault` or `OutputRoundsVault`) inheriting from `RoundsVaultBase`, passing the access manager address.  
3. **Grant `KEEPER_ROLE`** to the address that will call `nextRound()` and `setRoundSettled()`.  
4. **Grant `GOVERNOR_ROLE`** to the multisig that will manage the vault’s whitelist.  
5. **Use the vault’s own `setWhitelisted`** to add users before the first round opens.  
6. **Set initial round state** (the constructor sets round 0 as `Opened`).  

### 6.3 Admirals Quarters Integration

1. **Deploy the Admirals Quarters contract** (not shown in provided code).  
2. **Grant `ADMIRALS_QUARTERS_ROLE`** to the AQ contract address in the access manager.  
3. **For each fleet** that AQ will interact with, grant `OPERATOR_ROLE` (contract‑specific) to the AQ contract.  
4. Ensure AQ contract is **not** itself whitelisted (since it bypasses whitelist anyway via operator role).  

---

## 7. Security Considerations

- **Governor role** is highly privileged; it should be held by a multisig or DAO with time‑locked proposals.  
- **Whitelist manager** can open the global gateway (`address(0)`) – this should be carefully controlled.  
- **Operator role** allows unrestricted deposits/withdrawals for that contract. It must be assigned only to trusted, audited contracts (like AQ).  
- **Keeper role** for rounds must be trusted to call `nextRound` at the correct time; otherwise users cannot deposit or redeem.  
- **Guardian role** has emergency powers but with expiration to limit its window of use.  

---

## 8. Appendix: Role Derivation in Code

- **Contract‑specific roles** are generated as:  
  ```solidity
  keccak256(abi.encodePacked(roleName, roleTargetContract))
  ```  
- **OPERATOR_ROLE** for a fleet:  
  `keccak256(abi.encodePacked(ContractSpecificRoles.OPERATOR_ROLE, fleetAddress))`  
- **KEEPER_ROLE** for a fleet:  
  `keccak256(abi.encodePacked(ContractSpecificRoles.KEEPER_ROLE, fleetAddress))`  

All role checks in the contract use `_accessManager.hasRole(role, account)` (for global roles) or `_accessManager.hasRole(generateRole(...), account)` (for contract‑specific roles).

---

This document should serve as a comprehensive guide for institutional stakeholders to understand the access control architecture and to correctly configure roles and whitelists for each integration. For any further details, refer to the actual source code comments and the deployment scripts.