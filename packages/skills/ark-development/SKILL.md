---
name: ark-development
description: Comprehensive guide for developing new Ark contracts for the Summer Earn Protocol. Covers architecture, required overrides, testing patterns, gotchas, and code style conventions.
---

# Ark Development

Guide for implementing new Ark contracts that integrate external DeFi protocols with the Summer Earn Protocol's Fleet system.

## When to Use This Skill

- Building a new Ark for an external protocol (lending, staking, vault, LP, etc.)
- Reviewing or auditing an existing Ark implementation
- Debugging Ark integration issues (fork tests, valuation, withdrawal failures)

## Architecture Decision: Which Base Contract?

| Pattern | Base Contract | When to Use | Examples |
|---------|--------------|-------------|---------|
| Synchronous | `Ark` | Protocol returns assets immediately on withdraw | `AaveV3Ark`, `CompoundV3Ark`, `SparkArk`, `SkyUsdsArk`, `MoonwellArk`, `SiUSDArk` |
| Synchronous ERC4626 | `ERC4626Ark` (extends `Ark`) | Protocol is a standard ERC4626 vault | `MorphoV2VaultArk`, `FluidFTokenArk` |
| Multi-step synchronous | `Ark` | Protocol requires token conversion (e.g., USDC→USDS→sUSDS→ERC4626) | `PsmLiteERC4626Ark`, `Psm3ERC4626Ark`, `SiUSDArk`, `OriginUSDArk` |
| Asynchronous | `ArkWithWithdrawalRequest` (extends `Ark`) | Protocol has a withdrawal delay / request-claim cycle | `SyrupArk`, `SyrupArkV2`, `FluidLiteArk`, `OriginETHArk`, `OriginSuperOETHArk`, `AeraArk`, `ArmArk`, `MapleInstitutionalArk`, `UpshiftArk` |
| Pendle family | `BasePendleArk` (extends `Ark`) | Pendle LP or PT positions | `PendleLPArk`, `PendlePTArk`, `PendlePtOracleArk` |

## Required Overrides

Every Ark **must** implement these abstract functions from `Ark.sol`:

```solidity
function totalAssets() external view returns (uint256);
function _board(uint256 amount, bytes calldata data) internal;
function _disembark(uint256 amount, bytes calldata data) internal;
function _harvest(bytes calldata data) internal returns (address[] memory, uint256[] memory);
function _withdrawableTotalAssets() internal view returns (uint256);
function _validateBoardData(bytes calldata data) internal;
function _validateDisembarkData(bytes calldata data) internal;
```

`ArkWithWithdrawalRequest` Arks must additionally implement:
- `requestWithdrawal(uint256 amount)` — initiate withdrawal (keeper-only)
- `claimWithdrawal()` — claim processed withdrawal (keeper-only, no-op for some protocols)
- `isWithdrawalClaimRequired()` — whether explicit claim is needed
- `withdrawalRequestId()` — current request ID
- `withdrawUsingSwap(uint256 amount, bytes calldata data)` — instant exit via swap
- `assetsInWithdrawalQueue()` — value of escrowed/pending assets

## Implementation Rules

### 1. `totalAssets()` Must Return Asset-Denominated Value
- Must return the value in the **base asset's decimals** (e.g., 6 for USDC).
- Must account for all positions: idle base asset + intermediate tokens + yield-bearing tokens.
- For `ArkWithWithdrawalRequest`, include: `_withdrawableTotalAssets() + assetsInWithdrawalQueue() + value of shares held`.
- Must reflect **post-fee** values when the protocol charges withdrawal/burn fees.

### 2. `_board()` Must Not Leave Idle Assets
- After `_board` completes, the base asset balance of the Ark should be zero (all deposited).
- For multi-step paths, approve and convert in sequence within a single call.
- Use `forceApprove` (not `approve`) for all approvals.

### 3. `_disembark()` Handling
- **Synchronous Arks**: Must withdraw exact `amount` of base asset. After `_disembark`, the Ark must hold at least `amount` of the base asset — the base `Ark.disembark()` calls `asset.safeTransfer(msgSender, amount)` immediately after.
- **Async Arks**: `_disembark` is typically a no-op. Withdrawals go through `requestWithdrawal` → `claimWithdrawal` → `sweep` cycle.
- **Full withdrawal**: Use `redeem(allShares)` instead of `withdraw(totalAssets())`. Some vaults have rounding where `previewWithdraw` rounds up and causes reverts.

### 4. `_withdrawableTotalAssets()` Must Be Conservative
- Used by `FleetCommander` for withdrawal planning. Over-reporting causes reverts.
- For synchronous Arks: return `min(positionValue, availableLiquidity)`.
- For async Arks: return only the base asset balance held directly by the Ark (already-claimed funds).
- Check protocol-specific constraints: paused markets, frozen assets.

### 5. `_harvest()` — Auto-Compounding vs. External Rewards
- If yield auto-compounds (e.g., ERC4626 share price growth), return `[address(0)]` / `[0]` arrays.
- If the protocol has claimable rewards, claim them and send to `raft()`. Return array of calimed token addresses and amounts ( stick to the interface)
- The base `harvest()` emits `ArkHarvested` — only emit again if overriding the internal function directly.

### 6. Approvals in Constructor
- Don't set max approvals in the constructor for all token paths: `config.asset.forceApprove(protocolAddress, Constants.MAX_UINT256)`.
- Approve per-transaction in `_board`/`_disembark` only when the protocol requires exact amounts (e.g., `forceApprove(address, amount)` pattern seen in `CompoundV3Ark`, `AaveV3Ark`).

## Gotchas & Common Mistakes

### Fork Test Setup Order
**The fork must be created BEFORE `initializeCoreContracts()`**. The `ArkTestBase` deploys contracts on the active fork.

```solidity
// ✅ CORRECT
function setUp() public {
    forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
    initializeCoreContracts();
}

// ❌ WRONG — contracts won't exist on the fork
function setUp() public {
    initializeCoreContracts();
    forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
}
```

### Diamond Inheritance with Custom Interfaces
If your Ark overrides `totalAssets()` and inherits a custom interface that extends `IArk`, specify both in the `override` keyword:
```solidity
function totalAssets() public view override(Ark, IArk) returns (uint256 assets) { ... }
```

### Error Naming
`InvalidVaultAddress` and `ERC4626AssetMismatch` are already defined in `IArkConfigProviderErrors`. Do NOT redeclare them in your custom error interface — Solidity will throw a compilation error about duplicate definitions in the diamond.

### Decimal Scaling Between Tokens
When converting between tokens with different decimals (e.g., USDC 6 → iUSD 18), store a conversion factor and use it consistently. See `PsmLiteERC4626Ark` and `SiUSDArk` for patterns.

### `block.timestamp` for Deadlines
Use `block.timestamp` for protocol deadline parameters to prevent stale transactions.

### `requiresKeeperData` Flag
Set `requiresKeeperData: true` in ArkParams if your `_board`/`_disembark` functions require calldata (e.g., merkle proofs for FluidFTokenArk harvest). When true, `withdrawableTotalAssets()` returns 0 at the public level.

## Code Style

### Interface / Error / Event Files

Every new Ark must have a dedicated interface that extends `IArk` plus separate error and event interfaces:

```
src/interfaces/arks/IMyArk.sol       → extends IArk + IMyArkErrors + IMyArkEvents
src/errors/arks/IMyArkErrors.sol     → custom errors only
src/events/arks/IMyArkEvents.sol     → custom events only
```

Example (`ICapArk`):
```solidity
// src/interfaces/arks/ICapArk.sol
import {IArk} from "../IArk.sol";
import {ICapArkErrors} from "../../errors/arks/ICapArkErrors.sol";
import {ICapArkEvents} from "../../events/arks/ICapArkEvents.sol";

interface ICapArk is IArk, ICapArkEvents, ICapArkErrors {}

// src/errors/arks/ICapArkErrors.sol
interface ICapArkErrors {
    // Custom errors for the protocol go here
}

// src/events/arks/ICapArkEvents.sol
interface ICapArkEvents {
    // Custom events go here
}
```

If there are no custom errors/events, the interfaces can be empty. Some older Arks declare errors inline at the file level — new Arks should use the split pattern above.

### Contract Layout Order
1. Imports (local interface `IMyArk`, types, base contracts, OpenZeppelin, external)
2. Contract declaration with inheritance (implements `IMyArk`)
3. `using` directives
4. Constants / Immutables
5. Constructor
6. External/Public functions (`totalAssets`, `assetsInWithdrawalQueue`, `requestWithdrawal`, etc.)
7. Internal functions (`_board`, `_disembark`, `_harvest`, `_withdrawableTotalAssets`, helpers, validators)

### Naming
- **Constants**: `SCREAMING_SNAKE_CASE` with `public constant`
- **Immutables**: `camelCase` with `public immutable` (e.g., `vault`, `comet`) — some older Arks use SCREAMING_SNAKE_CASE
- **Constructor params**: prefixed with `_` (e.g., `_vault`, `_router`)
- **NatSpec**: Use `@inheritdoc Ark` or `@inheritdoc IArk` for overridden functions

## Testing Patterns

### Fork Test Structure
```solidity
contract MyArkTestFork is Test, IArkEvents, ArkTestBase {
    MyArk public ark;
    uint256 forkId;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
        initializeCoreContracts();
        // deploy ark, grant roles, register fleet
        (address fleetAddr, ) = setupFleetCommanderWithBufferArk(assetAddress, "TestFleet");
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), fleetAddr);
        vm.stopPrank();
        vm.prank(fleetAddr);
        ark.registerFleetCommander();
    }
}
```

### Minimum Test Cases
1. **Board**: Deposit base asset, verify `totalAssets()` ≈ deposit amount.
2. **Full Disembark**: Board → disembark all → verify Ark is empty, commander received funds.
3. **Partial Disembark**: Board → disembark partial → verify remaining position and received funds.
4. **Yield Accrual** (if applicable): Board → simulate yield → verify `totalAssets()` increased.
5. **Access Control**: Verify board/disembark revert for non-commander, harvest reverts for non-raft.

**Additional test cases for async Arks** (`ArkWithWithdrawalRequest`):

6. **Request Partial Withdrawal**: Board → `requestWithdrawal(partialAmount)` → verify `assetsInWithdrawalQueue()` reflects escrowed value and `totalAssets()` still accounts for all positions.
7. **Request Full Withdrawal**: Board → `requestWithdrawal(type(uint256).max)` → verify all shares are escrowed, `withdrawalRequestId() > 0`.
8. **Claim Withdrawal + Sweep**: Request → simulate protocol processing → `claimWithdrawal()` (if `isWithdrawalClaimRequired()`) → `sweep()` → verify funds arrive in buffer ark.
9. **Withdraw Using Swap**: Board → whitelist a router → `withdrawUsingSwap(amount, swapData)` → verify funds reach buffer ark, slippage enforced.
10. **Withdraw Using Swap — Non-Whitelisted Router**: Verify `withdrawUsingSwap` reverts with `RouterNotWhitelisted`.
11. **Duplicate Request Revert**: Request withdrawal → request again before claim → verify revert (`WithdrawalAlreadyRequested` or protocol-specific error).
12. **`withdrawableTotalAssets` Isolation**: Board → request withdrawal → verify `_withdrawableTotalAssets()` returns only the directly-held asset balance, not escrowed/pending shares.

### Assertions
- Use `assertApproxEqAbs` for amounts subject to fees or rounding (document tolerance).
- Use `assertGt` / `assertEq` for strict invariants.

## Reference Implementations

| Pattern | Contract | Notes |
|---------|----------|-------|
| Simple ERC4626 | `ERC4626Ark.sol` | Baseline for standard vaults |
| ERC4626 with harvest | `FluidFTokenArk.sol` | Merkle-based reward claiming |
| ERC4626 with custom liquidity | `MorphoV2VaultArk.sol` | Overrides `_withdrawableTotalAssets` |
| Multi-step synchronous | `SiUSDArk.sol` | USDC → iUSD → siUSD via Gateway |
| PSM + ERC4626 | `PsmLiteERC4626Ark.sol` | USDC → USDS → (sUSDS) → ERC4626 |
| Lending protocol | `AaveV3Ark.sol` | Direct supply/withdraw with reward harvesting |
| Lending (Aave fork) | `HyperlendArk.sol`, `HypurrfiArk.sol` | Same pattern, different interfaces |
| Lending (Compound fork) | `CompoundV3Ark.sol` | Comet supply/withdraw |
| Async withdrawal (Maple) | `SyrupArkV2.sol`, `MapleInstitutionalArk.sol` | Queue-based withdrawal with swap exit |
| Async withdrawal (Upshift) | `UpshiftArk.sol` | Date-based withdrawal epochs |
| Async withdrawal (Fluid) | `FluidLiteArk.sol` | Wrapper-based withdrawal queue |
| Pendle positions | `PendleLPArk.sol`, `PendlePTArk.sol` | Via `BasePendleArk` |
