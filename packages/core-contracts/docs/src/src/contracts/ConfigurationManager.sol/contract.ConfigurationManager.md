# ConfigurationManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/ConfigurationManager.sol)

**Inherits:**
[IConfigurationManager](/src/interfaces/IConfigurationManager.sol/interface.IConfigurationManager.md), [ProtocolAccessManaged](/src/contracts/ProtocolAccessManaged.sol/contract.ProtocolAccessManaged.md)

Manages system-wide configuration parameters for the protocol

*Implements the IConfigurationManager interface and inherits from ProtocolAccessManaged*


## State Variables
### initialized

```solidity
bool public initialized;
```


### _raft
The address of the Raft contract

*This is where rewards and farmed tokens are sent for processing*


```solidity
address public _raft;
```


### _tipJar
The address of the TipJar contract

*This is the contract that owns tips and is responsible for
dispensing them to claimants*


```solidity
address public _tipJar;
```


### _treasury
The address of the Treasury contract

*This is the contract that owns the treasury and is responsible for
dispensing funds to the protocol's operations*


```solidity
address public _treasury;
```


## Functions
### raft


```solidity
function raft() external view override returns (address);
```

### tipJar


```solidity
function tipJar() external view override returns (address);
```

### treasury


```solidity
function treasury() external view override returns (address);
```

### constructor

Constructs the ConfigurationManager contract


```solidity
constructor(address _accessManager) ProtocolAccessManaged(_accessManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_accessManager`|`address`|The address of the ProtocolAccessManager contract|


### initialize


```solidity
function initialize(ConfigurationManagerParams memory params) external onlyGovernor;
```

### setRaft

Sets a new address for the Raft contract

*Can only be called by the governor*

*Emits a RaftUpdated event*


```solidity
function setRaft(address newRaft) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRaft`|`address`|The new address for the Raft contract|


### setTipJar

Sets a new address for the TipJar contract

*Can only be called by the governor*

*Emits a TipJarUpdated event*


```solidity
function setTipJar(address newTipJar) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipJar`|`address`|The new address for the TipJar contract|


### setTreasury

Sets a new address for the Treasury contract

*Can only be called by the governor*

*Emits a TreasuryUpdated event*


```solidity
function setTreasury(address newTreasury) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTreasury`|`address`|The new address for the Treasury contract|


