# IHarborCommand
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/IHarborCommand.sol)

**Inherits:**
[IHarborCommandErrors](/src/errors/IHarborCommandErrors.sol/interface.IHarborCommandErrors.md)

Interface for the HarborCommand contract which manages FleetCommanders and TipJar

*This interface defines the external functions and events for HarborCommand*


## Functions
### enlistFleetCommander

Enlists a new FleetCommander

*Only callable by the governor*


```solidity
function enlistFleetCommander(address _fleetCommander) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fleetCommander`|`address`|The address of the FleetCommander to enlist|


### decommissionFleetCommander

Decommissions an enlisted FleetCommander

*Only callable by the governor*


```solidity
function decommissionFleetCommander(address _fleetCommander) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fleetCommander`|`address`|The address of the FleetCommander to decommission|


### getActiveFleetCommanders

Retrieves the list of active FleetCommanders


```solidity
function getActiveFleetCommanders() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|An array of addresses representing the active FleetCommanders|


### activeFleetCommanders

Checks if a FleetCommander is currently active


```solidity
function activeFleetCommanders(address _fleetCommander) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_fleetCommander`|`address`|The address of the FleetCommander to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the FleetCommander is active, false otherwise|


### fleetCommandersList

Retrieves the FleetCommander at a specific index in the list


```solidity
function fleetCommandersList(uint256 index) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index in the list of FleetCommanders|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the FleetCommander at the specified index|


