# CooldownNotElapsed
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol)

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

