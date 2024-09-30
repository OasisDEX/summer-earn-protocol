# ITipJar
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/interfaces/ITipJar.sol)

**Inherits:**
[ITipJarEvents](/src/events/ITipJarEvents.sol/interface.ITipJarEvents.md), [ITipJarErrors](/src/errors/ITipJarErrors.sol/interface.ITipJarErrors.md)

Interface for the TipJar contract, which manages the collection and distribution of tips

*This contract allows for the creation, modification, and removal of tip streams,
as well as the distribution of accumulated tips to recipients*


## Functions
### addTipStream

Adds a new tip stream


```solidity
function addTipStream(address recipient, Percentage allocation, uint256 lockedUntilEpoch) external;
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
function removeTipStream(address recipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient to remove|


### updateTipStream

Updates an existing tip stream


```solidity
function updateTipStream(address recipient, Percentage newAllocation, uint256 newLockedUntilEpoch) external;
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
|`<none>`|`TipStream[]`|An array of TipStream structs containing all tip stream information|


### getTotalAllocation

Calculates the total allocation percentage across all tip streams


```solidity
function getTotalAllocation() external view returns (Percentage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Percentage`|The total allocation as a Percentage|


### shake

Distributes accumulated tips from a single FleetCommander


```solidity
function shake(address fleetCommander) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander contract to distribute tips from|


### shakeMultiple

Distributes accumulated tips from multiple FleetCommanders


```solidity
function shakeMultiple(address[] calldata fleetCommanders) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommanders`|`address[]`|An array of FleetCommander contract addresses to distribute tips from|


## Structs
### TipStream
Struct representing a tip stream


```solidity
struct TipStream {
    address recipient;
    Percentage allocation;
    uint256 lockedUntilEpoch;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the tip stream recipient|
|`allocation`|`Percentage`|The percentage of tips allocated to this stream|
|`lockedUntilEpoch`|`uint256`|The epoch until which this tip stream is locked and cannot be modified|

