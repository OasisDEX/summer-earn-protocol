# FleetCommanderCache
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/FleetCommanderCache.sol)


## Functions
### _totalAssets


```solidity
function _totalAssets(address[] memory arks, IArk bufferArk) internal view returns (uint256 total);
```

### _withdrawableTotalAssets


```solidity
function _withdrawableTotalAssets(
    address[] memory arks,
    IArk bufferArk,
    mapping(address => bool) storage isArkWithdrawable
)
    internal
    view
    returns (uint256 withdrawableTotalAssets);
```

### _getAllArks

Retrieves an array of all Arks, including regular Arks and the buffer Ark

*This function creates a new array that includes all regular Arks and appends the buffer Ark at the end*


```solidity
function _getAllArks(address[] memory arks, IArk bufferArk) private pure returns (IArk[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IArk[]`|An array of IArk interfaces representing all Arks in the system|


### _sumTotalAssets

Calculates the sum of total assets across all provided Arks

*This function iterates through the provided array of Arks and accumulates their total assets*


```solidity
function _sumTotalAssets(IArk[] memory _arks) private view returns (uint256 total);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_arks`|`IArk[]`|An array of IArk interfaces representing the Arks to sum assets from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`total`|`uint256`|The sum of total assets across all provided Arks|


### _flushCache

Flushes the cache for all arks and related data

*This function resets the cached data for all arks and related data
to ensure that the next call to `totalAssets` or `withdrawableTotalAssets`
recalculates the values based on the current state of the arks.*


```solidity
function _flushCache() internal;
```

### _getArksData

Retrieves the data (address, totalAssets) for all arks and the buffer ark


```solidity
function _getArksData(address[] memory arks, IArk bufferArk) internal returns (ArkData[] memory _arksData);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_arksData`|`ArkData[]`|An array of ArkData structs containing the ark addresses and their total assets|


### _getStorageSlot

Retrieves a storage slot based on the provided prefix and index


```solidity
function _getStorageSlot(bytes32 prefix, uint256 index) internal pure returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`prefix`|`bytes32`|The prefix for the storage slot|
|`index`|`uint256`|The index for the storage slot|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|bytes32 The storage slot value|


### _getWithdrawableArksDataFromCache

Retrieves the data (address, totalAssets) for all withdrawable arks from cache


```solidity
function _getWithdrawableArksDataFromCache() internal view returns (ArkData[] memory arksData);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`arksData`|`ArkData[]`|An array of ArkData structs containing the ark addresses and their total assets|


### _cacheArks

Caches the data for all arks in the specified storage slots


```solidity
function _cacheArks(
    ArkData[] memory arksData,
    bytes32 totalAssetsPrefix,
    bytes32 addressPrefix,
    bytes32 lengthSlot
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`arksData`|`ArkData[]`|The array of ArkData structs containing the ark addresses and their total assets|
|`totalAssetsPrefix`|`bytes32`|The prefix for the ark total assets storage slot|
|`addressPrefix`|`bytes32`|The prefix for the ark addresses storage slot|
|`lengthSlot`|`bytes32`|The storage slot containing the number of arks|


### _cacheAllArks

Caches the data for all arks in the specified storage slots


```solidity
function _cacheAllArks(ArkData[] memory _arksData) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_arksData`|`ArkData[]`|The array of ArkData structs containing the ark addresses and their total assets|


### _cacheWithdrawableArksTotalAssetsArray

Caches the data for all withdrawable arks in the specified storage slots


```solidity
function _cacheWithdrawableArksTotalAssetsArray(ArkData[] memory _withdrawableArksData) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_withdrawableArksData`|`ArkData[]`|The array of ArkData structs containing the ark addresses and their total assets|


### _getWithdrawableArksData

Retrieves data for withdrawable arks, using pre-fetched data for all arks

*This function filters and sorts withdrawable arks by total assets*


```solidity
function _getWithdrawableArksData(
    address[] memory arks,
    IArk bufferArk,
    mapping(address => bool) storage isArkWithdrawable
)
    internal;
```

### _cacheAllArksTotalAssets

Caches the total assets for all arks in the specified storage slot


```solidity
function _cacheAllArksTotalAssets(uint256 totalAssets) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalAssets`|`uint256`|The total assets to cache|


### _cacheWithdrawableArksTotalAssets

Caches the total assets for all withdrawable arks in the specified storage slot


```solidity
function _cacheWithdrawableArksTotalAssets(uint256 withdrawableTotalAssets) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`withdrawableTotalAssets`|`uint256`|The total assets to cache|


### _sortArkDataByTotalAssets

Sorts the ArkData structs based on their total assets in ascending order

*This function implements a simple bubble sort algorithm*


```solidity
function _sortArkDataByTotalAssets(ArkData[] memory arkDataArray) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`arkDataArray`|`ArkData[]`|An array of ArkData structs to be sorted|


