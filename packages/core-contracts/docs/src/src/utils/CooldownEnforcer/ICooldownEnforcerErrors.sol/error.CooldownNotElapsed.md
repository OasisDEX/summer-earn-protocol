# CooldownNotElapsed
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol)

Emitted by the modifier when the cooldown period has not elapsed.


```solidity
error CooldownNotElapsed(uint256 lastActionTimestamp, uint256 cooldown, uint256 currentTimestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lastActionTimestamp`|`uint256`|The timestamp of the last action in Epoch time (block timestamp).|
|`cooldown`|`uint256`|The cooldown period in seconds.|
|`currentTimestamp`|`uint256`|The current block timestamp.|

