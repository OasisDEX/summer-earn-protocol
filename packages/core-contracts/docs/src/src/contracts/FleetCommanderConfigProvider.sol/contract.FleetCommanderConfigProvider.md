# FleetCommanderConfigProvider
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/FleetCommanderConfigProvider.sol)

**Inherits:**
[IFleetCommanderConfigProvider](/src/interfaces/IFleetCommanderConfigProvider.sol/interface.IFleetCommanderConfigProvider.md), [ProtocolAccessManaged](/src/contracts/ProtocolAccessManaged.sol/contract.ProtocolAccessManaged.md)

This contract provides configuration management for the FleetCommander


## State Variables
### config

```solidity
FleetConfig public config;
```


### arks

```solidity
address[] public arks;
```


### isArkActive

```solidity
mapping(address => bool) public isArkActive;
```


### isArkWithdrawable

```solidity
mapping(address => bool) public isArkWithdrawable;
```


### MAX_REBALANCE_OPERATIONS

```solidity
uint256 public constant MAX_REBALANCE_OPERATIONS = 10;
```


## Functions
### constructor


```solidity
constructor(FleetCommanderParams memory params) ProtocolAccessManaged(params.accessManager);
```

### getArks


```solidity
function getArks() public view returns (address[] memory);
```

### getConfig


```solidity
function getConfig() external view override returns (FleetConfig memory);
```

### addArk


```solidity
function addArk(address ark) external onlyGovernor;
```

### addArks


```solidity
function addArks(address[] calldata _arkAddresses) external onlyGovernor;
```

### removeArk


```solidity
function removeArk(address ark) external onlyGovernor;
```

### setArkDepositCap


```solidity
function setArkDepositCap(address ark, uint256 newDepositCap) external onlyGovernor;
```

### setArkMaxRebalanceOutflow


```solidity
function setArkMaxRebalanceOutflow(address ark, uint256 newMaxRebalanceOutflow) external onlyGovernor;
```

### setArkMaxRebalanceInflow


```solidity
function setArkMaxRebalanceInflow(address ark, uint256 newMaxRebalanceInflow) external onlyGovernor;
```

### setMinimumBufferBalance


```solidity
function setMinimumBufferBalance(uint256 newMinimumBalance) external onlyGovernor;
```

### setFleetDepositCap


```solidity
function setFleetDepositCap(uint256 newCap) external onlyGovernor;
```

### setMaxRebalanceOperations


```solidity
function setMaxRebalanceOperations(uint256 newMaxRebalanceOperations) external onlyGovernor;
```

### setFleetConfig


```solidity
function setFleetConfig(FleetConfig memory _config) internal;
```

### _addArk


```solidity
function _addArk(address ark) internal;
```

### _removeArk


```solidity
function _removeArk(address ark) internal;
```

### _setupArks


```solidity
function _setupArks(address[] memory _arkAddresses) internal;
```

### _validateArkRemoval


```solidity
function _validateArkRemoval(address ark) internal view;
```

