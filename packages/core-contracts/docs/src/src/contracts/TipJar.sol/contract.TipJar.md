# TipJar
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/TipJar.sol)

**Inherits:**
[ITipJar](/src/interfaces/ITipJar.sol/interface.ITipJar.md), [ProtocolAccessManaged](/src/contracts/ProtocolAccessManaged.sol/contract.ProtocolAccessManaged.md)

Contract implementing the centralized collection and distribution of tips

*This contract manages tip streams, allowing for the addition, removal, and updating of tip allocations*


## State Variables
### tipStreams

```solidity
mapping(address recipient => TipStream tipStream) public tipStreams;
```


### tipStreamRecipients

```solidity
address[] public tipStreamRecipients;
```


### manager

```solidity
IConfigurationManager public manager;
```


## Functions
### constructor

Constructs a new TipJar contract


```solidity
constructor(address _accessManager, address _configurationManager) ProtocolAccessManaged(_accessManager);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_accessManager`|`address`|The address of the access manager contract|
|`_configurationManager`|`address`|The address of the configuration manager contract|


### addTipStream

Adds a new tip stream


```solidity
function addTipStream(address recipient, Percentage allocation, uint256 lockedUntilEpoch) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient|
|`allocation`|`Percentage`|The percentage of tips allocated to this stream|
|`lockedUntilEpoch`|`uint256`|The epoch until which this tip stream is locked|


### removeTipStream

Removes an existing tip stream


```solidity
function removeTipStream(address recipient) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient to remove|


### updateTipStream

Updates an existing tip stream


```solidity
function updateTipStream(
    address recipient,
    Percentage newAllocation,
    uint256 newLockedUntilEpoch
)
    external
    onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient to update|
|`newAllocation`|`Percentage`|The new percentage allocation for the tip stream|
|`newLockedUntilEpoch`|`uint256`|The new epoch until which this tip stream is locked|


### getTipStream

Retrieves information about a specific tip stream


```solidity
function getTipStream(address recipient) external view returns (TipStream memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`TipStream`|TipStream struct containing the tip stream information|


### getAllTipStreams

Retrieves information about all tip streams


```solidity
function getAllTipStreams() external view returns (TipStream[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`TipStream[]`|allStreams An array of TipStream structs containing all tip stream information|


### shake

Distributes accumulated tips from a single FleetCommander


```solidity
function shake(address fleetCommander_) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander_`|`address`|The address of the FleetCommander contract to distribute tips from|


### shakeMultiple

Distributes accumulated tips from multiple FleetCommanders


```solidity
function shakeMultiple(address[] calldata fleetCommanders) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommanders`|`address[]`|An array of FleetCommander contract addresses to distribute tips from|


### getTotalAllocation

Calculates the total allocation percentage across all tip streams


```solidity
function getTotalAllocation() public view returns (Percentage total);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`total`|`Percentage`|The total allocation as a Percentage|


### _shake

Distributes accumulated tips from a single FleetCommander


```solidity
function _shake(address fleetCommander_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander_`|`address`|The address of the FleetCommander contract to distribute tips from|


### _validateTipStream

Validates that a tip stream exists and is not locked


```solidity
function _validateTipStream(address recipient) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient|


### _validateTipStreamAllocation

Validates the allocation for a tip stream


```solidity
function _validateTipStreamAllocation(Percentage allocation) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`allocation`|`Percentage`|The allocation to validate|


