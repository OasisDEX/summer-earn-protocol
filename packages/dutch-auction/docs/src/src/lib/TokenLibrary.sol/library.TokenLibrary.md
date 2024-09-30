# TokenLibrary
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/lib/TokenLibrary.sol)

**Author:**
halaprix

This library provides utility functions for handling token decimals and conversions

*Implements functions to get token decimals and convert amounts between different decimal representations*


## Functions
### getDecimals

Retrieves the number of decimals for a given token

*Uses a low-level call to get the decimals, defaulting to 18 if the call fails*

*Process:
1. Attempts to call the 'decimals()' function on the token contract
2. If the call succeeds, decodes and returns the result
3. If the call fails, returns 18 as a default value*

*Note: This function assumes that tokens follow the ERC20 standard.
Non-standard tokens may cause unexpected behavior.*


```solidity
function getDecimals(IERC20 token) internal view returns (uint8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The ERC20 token to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimals for the token|


### toWei

Converts an amount from its original decimal representation to 18 decimals (wei)

*Adjusts the amount based on the difference between the original decimals and 18*

*Calculation:
- If decimals == 18, no conversion needed
- If decimals > 18, divide by 10^(decimals - 18)
- If decimals < 18, multiply by 10^(18 - decimals)*

*Note: This function assumes that the input amount is in its original decimal representation.
Incorrect input decimals will lead to incorrect conversions.*


```solidity
function toWei(uint256 amount, uint8 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to convert|
|`decimals`|`uint8`|The original number of decimals|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount converted to 18 decimal representation|


### fromWei

Converts an amount from 18 decimals (wei) to a specified decimal representation

*Adjusts the amount based on the difference between 18 and the target decimals*

*Calculation:
- If decimals == 18, no conversion needed
- If decimals > 18, multiply by 10^(decimals - 18)
- If decimals < 18, divide by 10^(18 - decimals)*

*Note: This function assumes that the input amount is in 18 decimal representation.
Incorrect input amounts will lead to incorrect conversions.*


```solidity
function fromWei(uint256 amount, uint8 decimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount in 18 decimal representation to convert|
|`decimals`|`uint8`|The target number of decimals|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount converted to the specified decimal representation|


### convertDecimals

Converts an amount from one decimal representation to another

*Performs the conversion directly to avoid precision loss*

*Process:
1. If fromDecimals == toDecimals, no conversion needed
2. If fromDecimals < toDecimals, multiply by 10^(toDecimals - fromDecimals)
3. If fromDecimals > toDecimals, divide by 10^(fromDecimals - toDecimals)*

*Note: This function provides a more precise way to convert between any two decimal representations.
It avoids the intermediate step of converting to 18 decimals, which can cause precision loss.*


```solidity
function convertDecimals(uint256 amount, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to convert|
|`fromDecimals`|`uint8`|The original number of decimals|
|`toDecimals`|`uint8`|The target number of decimals|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount converted to the target decimal representation|


