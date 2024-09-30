# VotingDecayMath
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/VotingDecayMath.sol)


## State Variables
### WAD

```solidity
uint256 private constant WAD = 1e18;
```


## Functions
### mulDiv

*Multiplies two numbers and divides the result by a third number, using PRBMath for precision.*


```solidity
function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`uint256`|The first number to multiply|
|`b`|`uint256`|The second number to multiply|
|`denominator`|`uint256`|The number to divide by|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The result of (a * b) / denominator, using PRBMath's UD60x18 type|


### exponentialDecay

*Calculates the exponential decay using PRBMath's UD60x18 type.*


```solidity
function exponentialDecay(
    uint256 initialValue,
    uint256 decayRatePerSecond,
    uint256 decayTimeInSeconds
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialValue`|`uint256`|The initial value|
|`decayRatePerSecond`|`uint256`|The decay rate per second|
|`decayTimeInSeconds`|`uint256`|The time elapsed in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The decayed value|


### linearDecay

*Calculates the linear decay.*


```solidity
function linearDecay(
    uint256 initialValue,
    uint256 decayRatePerSecond,
    uint256 decayTimeInSeconds
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialValue`|`uint256`|The initial value|
|`decayRatePerSecond`|`uint256`|The decay rate per second|
|`decayTimeInSeconds`|`uint256`|The time elapsed in seconds|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The decayed value|


