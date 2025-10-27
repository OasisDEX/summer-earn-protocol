# Implementing a New Ark Contract

## Overview
An Ark is a contract that manages funds and interacts with external protocols (like Aave, Compound, etc.). It must inherit from either the base `Ark` contract or `ArkWithWithdrawalRequest` contract (for protocols requiring withdrawal requests) and implement several key functions.

## Ark Types

### Base Ark
The standard implementation that handles direct deposits and withdrawals to external protocols.

### ArkWithWithdrawalRequest
An extension of the base Ark that handles protocols requiring a withdrawal request before assets can be retrieved. This implementation adds:

- **Withdrawal Request Functionality**: Request and claim withdrawals in a two-step process
- **Token Swapping**: Ability to swap tokens using whitelisted routers
- **Slippage Control**: Configure and apply slippage tolerance for swaps
- **Sweep Functionality**: Move assets to a buffer ark

## Ark Classification

### Standard Arks (inherit from `Ark`)
- AaveV3Ark
- BufferArk
- CompoundV3Ark
- ERC4626Ark
- SkyRewardsArk
- SkyUsdsArk
- SkyUsdsPsm3Ark
- SparkArk
- BasePendleArk
- MoonwellArk
- MorphoArk
- MorphoVaultArk
- PendleLPArk
- PendlePTArk
- PendlePtOracleArk
- SiloVaultArk

### Withdrawal Request Arks (inherit from `ArkWithWithdrawalRequest`)
- FluidLiteArk
- OriginETHArk
- OriginSuperOETHArk
- SyrupArk

## Critical: Asset Amount Handling
⚠️ **IMPORTANT**: All amounts in `_board()` and `_disembark()` must be in the underlying asset's decimals (e.g., USDC = 6 decimals, WETH = 18 decimals). This is crucial even if the protocol uses a different token (like aUSD, cUSDC, etc.).

Example:
- If FleetCommander uses USDC (6 decimals)
- And Ark deposits to Aave's aUSDC (6 decimals)
- The amount parameter must be in USDC decimals (6)

## Required Functions

### 1. _board()
```solidity
function _board(uint256 amount, bytes calldata data) internal override
```
- Handles depositing assets into the external protocol
- `amount` is in underlying asset decimals (e.g., USDC = 6)
- Must maintain exact amount when depositing to protocol
- Example from AaveV3Ark:
```solidity
function _board(uint256 amount, bytes calldata) internal override {
    // amount is in USDC decimals (6)
    config.asset.forceApprove(address(aaveV3Pool), amount);
    // supply() will receive amount in USDC decimals
    aaveV3Pool.supply(address(config.asset), amount, address(this), 0);
}
```

### 2. _disembark()
```solidity
function _disembark(uint256 amount, bytes calldata data) internal override
```
- Handles withdrawing assets from the external protocol
- `amount` is in underlying asset decimals (e.g., USDC = 6)
- Must withdraw exact amount from protocol
- Example from AaveV3Ark:
```solidity
function _disembark(uint256 amount, bytes calldata) internal override {
    // amount is in USDC decimals (6)
    // withdraw() will receive amount in USDC decimals
    aaveV3Pool.withdraw(address(config.asset), amount, address(this));
}
```

### 3. totalAssets()
```solidity
function totalAssets() public view override returns (uint256)
```
- Returns the total underlying assets managed by the Ark
- Must return amount in underlying asset decimals
- Example from AaveV3Ark:
```solidity
function totalAssets() public view override returns (uint256) {
    // Returns balance in underlying asset decimals (e.g., USDC = 6)
    return IERC20(aToken).balanceOf(address(this));
}
```

### 4. _withdrawableTotalAssets()
```solidity
function _withdrawableTotalAssets() internal view override returns (uint256)
```
- Returns the amount of assets that can be withdrawn
- Must return amount in underlying asset decimals
- Example from AaveV3Ark:
```solidity
function _withdrawableTotalAssets() internal view override returns (uint256) {
    if (!(_isActive(configData) && !_isPaused(configData))) {
        return 0;
    }
    // Returns minimum of available liquidity and total assets
    // Both values are in underlying asset decimals
    return Math.min(assetsInAToken, _totalAssets);
}
```

### 5. _harvest()
```solidity
function _harvest(bytes calldata additionalData) internal override returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
```
- Collects rewards from the external protocol
- Returns arrays of reward token addresses and amounts
- Reward amounts should be in their respective token decimals
- Example from AaveV3Ark:
```solidity
function _harvest(bytes calldata) internal override returns (address[] memory rewardTokens, uint256[] memory rewardAmounts) {
    address[] memory incentivizedAssets = new address[](1);
    incentivizedAssets[0] = aToken;
    // claimAllRewards returns amounts in their respective token decimals
    return rewardsController.claimAllRewards(incentivizedAssets, raft());
}
```

## ArkWithWithdrawalRequest Additional Features

### Withdrawal Request Functions

#### requestWithdrawal()
```solidity
function requestWithdrawal(uint256 amount) external
```
- Initiates the withdrawal process for protocols requiring a request before claiming
- Callable only by the keeper

#### claimWithdrawal()
```solidity
function claimWithdrawal() external
```
- Claims previously requested withdrawals after the protocol's waiting period
- Callable only by the keeper
- SyrupArk doesnt require claiming, funds are sent directly to the ark

### Token Swap Functions

#### withdrawUsingSwap()
```solidity
function withdrawUsingSwap(uint256 amount, bytes calldata data) external
```
- Withdraws assets using a swap through a whitelisted router
- Allows instantaneous exit fro prtocols requiring withdrawal requests
- the `amount` is the amount of the underlying asset to be withdrawn from the ark 
  - OriginETH - the amount of tokens to swap ( encoded in `data`) is the amount of `totalAssets` ( balance of `OriginETH`)
  - Fluid Lite - the amount of tokens to swap ( encoded in `data`)  is the amount of `stETH` withdrawn from the vault ( original `amount` minus 0.05% withdrawal fee)
  - Syrup - the amount of tokens to swap ( encoded in `data`)  is the amount of shares (SyrupUSDC token) that will be swapped - can be computed using `convertToShares()` method in SyrupUSDC contract


#### whitelistRouter()
```solidity
function whitelistRouter(address router, bool isWhitelisted) external
```
- Adds or removes a router from the whitelist
- Callable only by the curator

#### setSlippage()
```solidity
function setSlippage(uint256 slippage) external
```
- Sets the maximum slippage allowed for swaps (base 10000)
- Callable only by the curator
- Maximum slippage is 10% (1000)

### Sweep Function

#### sweep()
```solidity
function sweep() external returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
```
- Sweeps all underlying assets from the Ark and boards them to bufferArk
- Callable only by the keeper

## Important Notes
1. Your Ark must inherit from either the base `Ark` contract or `ArkWithWithdrawalRequest`
2. All amounts in `_board()` and `_disembark()` must be in underlying asset decimals
3. Never convert amounts between different decimals in these functions
4. If protocol requires different decimals, handle conversion at the protocol interface level
5. Consider whether your protocol requires withdrawal requests when choosing the base contract
6. For token swaps, ensure proper slippage control and router whitelisting
7. Test thoroughly with different decimal combinations and withdrawal patterns
8. Consider implementing emergency withdrawal mechanisms
9. Test thoroughly with the FleetCommander integration
