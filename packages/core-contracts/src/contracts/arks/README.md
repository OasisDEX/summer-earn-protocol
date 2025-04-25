# Implementing a New Ark Contract

## Overview
An Ark is a contract that manages funds and interacts with external protocols (like Aave, Compound, etc.). It must inherit from the base `Ark` contract and implement several key functions.

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

## Important Notes
1. Your Ark must inherit from the base `Ark` contract
2. All amounts in `_board()` and `_disembark()` must be in underlying asset decimals
3. Never convert amounts between different decimals in these functions
4. If protocol requires different decimals, handle conversion at the protocol interface level
5. Test thoroughly with different decimal combinations
6. Consider implementing emergency withdrawal mechanisms
7. Test thoroughly with the FleetCommander integration
