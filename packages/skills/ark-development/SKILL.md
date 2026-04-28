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

Every Ark must answer one question first: **are deposits and withdrawals synchronous?**

| Pattern | Base Contract | When to Use | Example |
|---------|--------------|-------------|---------|
| Synchronous | `Ark` | Protocol returns assets immediately on withdraw | `AaveV3Ark`, `CapArk` |
| Synchronous ERC4626 | `ERC4626Ark` (extends `Ark`) | Protocol is a standard ERC4626 vault | `MorphoV2VaultArk`, `ERC4626Ark` |
| Asynchronous | `ArkWithWithdrawalRequest` (extends `Ark`) | Protocol has a withdrawal delay / request-claim cycle | `SyrupArk`, `WisdomTreeArk` |

### Multi-Step Conversion Paths

Some protocols require converting through an intermediate token (e.g., `USDC → cUSD → stcUSD`). In these cases, inherit directly from `Ark` and handle the conversion steps manually in `_board` and `_disembark`. See `CapArk` and `OriginUSDArk` for examples.

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

## Implementation Rules

### 1. `totalAssets()` Must Return Asset-Denominated Value

- Must return the value in the **base asset's decimals** (e.g., 6 for USDC).
- Must account for all positions: idle base asset + intermediate tokens + yield-bearing tokens.
- Must reflect **post-fee** values when the protocol charges withdrawal/burn fees.
- Never call external functions that can revert unexpectedly. Wrap in `try/catch` if needed.

### 2. `_board()` Must Not Leave Idle Assets

- After `_board` completes, the base asset balance of the Ark should be zero (all deposited).
- For multi-step paths, approve and convert in sequence within a single call.
- Use `forceApprove` (not `approve`) to handle tokens with non-standard approval behavior.

### 3. `_disembark()` Must Handle Full and Partial Withdrawals

This is the most error-prone function. Key rules:

- **Full withdrawal**: Use `redeem(allShares)` instead of `withdraw(totalAssets())`. Some vaults have rounding where `previewWithdraw` rounds up and causes reverts when withdrawing the exact `totalAssets()`.
- **Partial withdrawal**: Estimate the required intermediate amount, preview the output, and add a small buffer. Never use hardcoded percentages as buffers without documenting the source.
- **Critical**: After `_disembark`, the Ark must hold at least `amount` of the base asset. The base `Ark.disembark()` calls `asset.safeTransfer(msgSender, amount)` immediately after `_disembark`. If the Ark does not hold enough, the tx reverts.

### 4. `_withdrawableTotalAssets()` Must Be Conservative

- This is used by `FleetCommander` for withdrawal planning. Over-reporting causes reverts.
- Must return `min(positionValue, availableLiquidity)`.
- Some protocols (e.g., Morpho V2) return `0` from `maxWithdraw` intentionally. Override with a best-effort bound.
- Consider protocol-specific constraints: paused markets, frozen assets, fractional reserve limits.

### 5. `_harvest()` — Auto-Compounding vs. External Rewards

- If yield auto-compounds (e.g., ERC4626 share price growth), return empty arrays.
- If the protocol has claimable rewards, claim them and send to `raft()`.
- Emit `ArkHarvested` after claiming (the base `harvest()` does this, but if overriding check).

### 6. Approvals in Constructor

- Set max approvals in the constructor for all token paths. Use `forceApprove`.
- Never approve per-transaction inside `_board` or `_disembark` unless the protocol requires exact amounts.
- Pattern: `config.asset.forceApprove(protocolAddress, Constants.MAX_UINT256)`.

## Gotchas & Common Mistakes

### Fork Test Setup Order

**The fork must be created BEFORE `initializeCoreContracts()`**. The `ArkTestBase` deploys contracts (AccessManager, ConfigurationManager, etc.) which must exist on the active fork. If you deploy them first and then create a fork, the fork won't have those contracts.

```solidity
// ✅ CORRECT
function setUp() public {
    forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
    initializeCoreContracts(); // deploys on the fork
}

// ❌ WRONG — contracts deployed on fork 0, but fork 1 is active
function setUp() public {
    initializeCoreContracts();
    forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
}
```

### Diamond Inheritance with `ICapArk` / Custom Interfaces

If your Ark implements a custom interface that extends `IArk`, you must specify both contracts in the `override` keyword for `totalAssets()`:

```solidity
function totalAssets() public view override(Ark, IArk) returns (uint256 assets) { ... }
```

And explicitly import `IArk`:
```solidity
import {IArk} from "../../interfaces/IArk.sol";
```

### Error Naming Collisions

`InvalidVaultAddress` is already defined in `IArkConfigProviderErrors`. Do NOT redeclare it in your custom error interface. Solidity will throw a compilation error about duplicate error definitions in the diamond.

### Decimal Scaling Between Tokens

When converting between tokens with different decimals (e.g., USDC 6 → cUSD 18), use `Constants.WAD` (1e18) for scaling and store the asset decimals as an immutable:

```solidity
uint256 public immutable ASSET_DECIMALS;
// In constructor:
ASSET_DECIMALS = IERC20Metadata(address(config.asset)).decimals();
// In logic:
uint256 scaledAmount = (amount * Constants.WAD) / (10 ** ASSET_DECIMALS);
```

### Protocol Fee Estimation

Never use hardcoded fee buffers (e.g., `* 101 / 100`). Instead:
1. Use the protocol's preview/quote function to get an estimate.
2. If the preview shows a shortfall, scale proportionally.
3. Apply a named constant for the safety buffer (e.g., `BURN_ESTIMATE_BUFFER`).

### `block.timestamp` for Deadlines

When calling protocol functions that accept a deadline parameter, use `block.timestamp` — this ensures the tx is valid for the current block only and prevents stale transactions from being replayed.

## Code Style & File Organization

### Contract Layout Order

1. **Imports** (sorted: local interfaces first, then types, then base, then OpenZeppelin, then external)
2. **Contract declaration** with inheritance
3. **`using` directives**
4. **Constants** (named, documented)
5. **State variables** (immutables)
6. **Constructor**
7. **External / Public functions**
8. **Internal functions** (`_board`, `_disembark`, `_harvest`, `_withdrawableTotalAssets`, helpers, validators)

### Interface / Error / Event Files

Every Ark with custom errors or events must have:

```
src/interfaces/arks/IMyArk.sol       → extends IArk + errors + events
src/errors/arks/IMyArkErrors.sol     → custom errors only
src/events/arks/IMyArkEvents.sol     → custom events only
```

If there are no custom errors/events, the files can contain empty interfaces.

### Naming Conventions

- **Constants**: `SCREAMING_SNAKE_CASE`, with `public constant` visibility.
- **Immutables**: `SCREAMING_SNAKE_CASE`, with `public immutable` visibility.
- **Constructor params**: prefixed with `_` (e.g., `_cUSD`, `_stcUSD`).
- **NatSpec**: Use `@inheritdoc Ark` or `@inheritdoc IArk` for overridden functions. Do not repeat the base docstring.

### Comments

- Do not add obvious comments (e.g., `// Approve cUSD to spend USDC`).
- Do add comments for non-obvious logic: fee estimation strategies, rounding edge cases, protocol quirks.
- Remove all TODO and placeholder comments before merging.

## Testing Patterns

### Fork Test Structure

```solidity
contract MyArkTestFork is Test, IArkEvents, ArkTestBase {
    using SafeERC20 for IERC20;
    MyArk public ark;

    function setUp() public {
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
        initializeCoreContracts();
        // ... deploy ark, grant roles, register fleet
    }

    function test_Board_fork() public { ... }
    function test_Disembark_Full_fork() public { ... }
    function test_Disembark_Partial_fork() public { ... }
}
```

### Minimum Test Cases

1. **Board**: Deposit base asset, verify `totalAssets()` ≈ deposit amount (minus fees).
2. **Full Disembark**: Board → disembark all → verify Ark is empty, commander received funds.
3. **Partial Disembark**: Board → disembark partial → verify remaining position and received funds.
4. **Yield Accrual** (if applicable): Board → `vm.warp` → verify `totalAssets()` increased.
5. **Edge Cases**: Zero amount, max uint, liquidity-constrained withdrawals.

### Assertions

- Use `assertApproxEqAbs` for amounts subject to fees or rounding, with a documented tolerance.
- Use `assertGt` / `assertEq` for strict invariants (e.g., shares balance > 0 after deposit).

## Reference Implementations

| Pattern | Contract | Notes |
|---------|----------|-------|
| Simple ERC4626 | `ERC4626Ark.sol` | Baseline for standard vaults |
| ERC4626 with custom liquidity | `MorphoV2VaultArk.sol` | Overrides `_withdrawableTotalAssets` for non-standard `maxWithdraw` |
| Multi-step synchronous | `CapArk.sol` | USDC → cUSD → stcUSD with fee preview |
| Multi-step synchronous | `OriginUSDArk.sol` | USDC → OUSD with intermediate mint |
| Asynchronous withdrawal | `SyrupArk.sol` | Uses `ArkWithWithdrawalRequest` |
| Lending protocol | `AaveV3Ark.sol` | Direct supply/withdraw with reward harvesting |
