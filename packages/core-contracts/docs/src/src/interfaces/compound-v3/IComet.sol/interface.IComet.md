# IComet
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/compound-v3/IComet.sol)


## Functions
### borrowBalanceOf


```solidity
function borrowBalanceOf(address account) external view returns (uint256);
```

### supply


```solidity
function supply(address asset, uint256 amount) external;
```

### withdraw


```solidity
function withdraw(address asset, uint256 amount) external;
```

### getSupplyRate


```solidity
function getSupplyRate(uint256 utilization) external view returns (uint64);
```

### getUtilization


```solidity
function getUtilization() external view returns (uint256);
```

### balanceOf


```solidity
function balanceOf(address owner) external view returns (uint256);
```

## Events
### Supply

```solidity
event Supply(address indexed from, address indexed dst, uint256 amount);
```

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 amount);
```

### Withdraw

```solidity
event Withdraw(address indexed src, address indexed to, uint256 amount);
```

### SupplyCollateral

```solidity
event SupplyCollateral(address indexed from, address indexed dst, address indexed asset, uint256 amount);
```

### TransferCollateral

```solidity
event TransferCollateral(address indexed from, address indexed to, address indexed asset, uint256 amount);
```

### WithdrawCollateral

```solidity
event WithdrawCollateral(address indexed src, address indexed to, address indexed asset, uint256 amount);
```

### AbsorbDebt
Event emitted when a borrow position is absorbed by the protocol


```solidity
event AbsorbDebt(address indexed absorber, address indexed borrower, uint256 basePaidOut, uint256 usdValue);
```

### AbsorbCollateral
Event emitted when a user's collateral is absorbed by the protocol


```solidity
event AbsorbCollateral(
    address indexed absorber,
    address indexed borrower,
    address indexed asset,
    uint256 collateralAbsorbed,
    uint256 usdValue
);
```

### BuyCollateral
Event emitted when a collateral asset is purchased from the protocol


```solidity
event BuyCollateral(address indexed buyer, address indexed asset, uint256 baseAmount, uint256 collateralAmount);
```

### PauseAction
Event emitted when an action is paused/unpaused


```solidity
event PauseAction(bool supplyPaused, bool transferPaused, bool withdrawPaused, bool absorbPaused, bool buyPaused);
```

### WithdrawReserves
Event emitted when reserves are withdrawn by the governor


```solidity
event WithdrawReserves(address indexed to, uint256 amount);
```

