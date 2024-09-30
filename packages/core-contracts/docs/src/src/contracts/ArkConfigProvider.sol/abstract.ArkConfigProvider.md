# ArkConfigProvider
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/ArkConfigProvider.sol)

**Inherits:**
[IArkConfigProvider](/src/interfaces/IArkConfigProvider.sol/interface.IArkConfigProvider.md), [ArkAccessManaged](/src/contracts/ArkAccessManaged.sol/contract.ArkAccessManaged.md)


## State Variables
### config

```solidity
ArkConfig public config;
```


### manager

```solidity
IConfigurationManager public manager;
```


## Functions
### constructor


```solidity
constructor(ArkParams memory _params) ArkAccessManaged(_params.accessManager);
```

### name


```solidity
function name() external view returns (string memory);
```

### raft


```solidity
function raft() public view returns (address);
```

### depositCap


```solidity
function depositCap() external view returns (uint256);
```

### token


```solidity
function token() external view returns (IERC20);
```

### commander


```solidity
function commander() external view returns (address);
```

### maxRebalanceOutflow


```solidity
function maxRebalanceOutflow() external view returns (uint256);
```

### maxRebalanceInflow


```solidity
function maxRebalanceInflow() external view returns (uint256);
```

### requiresKeeperData


```solidity
function requiresKeeperData() external view returns (bool);
```

### setDepositCap


```solidity
function setDepositCap(uint256 newDepositCap) external onlyCommander;
```

### setMaxRebalanceOutflow


```solidity
function setMaxRebalanceOutflow(uint256 newMaxRebalanceOutflow) external onlyCommander;
```

### setMaxRebalanceInflow


```solidity
function setMaxRebalanceInflow(uint256 newMaxRebalanceInflow) external onlyCommander;
```

