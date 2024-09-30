# ICooldownEnforcer
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/utils/CooldownEnforcer/ICooldownEnforcer.sol)

Enforces a cooldown period between actions. It provides the basic management for a cooldown
period, allows to update the cooldown period and provides a modifier to enforce the cooldown.


## Functions
### getCooldown

VIEW FUNCTIONS

Returns the cooldown period in seoonds.


```solidity
function getCooldown() external view returns (uint256);
```

### getLastActionTimestamp

Returns the timestamp of the last action in Epoch time (block timestamp).


```solidity
function getLastActionTimestamp() external view returns (uint256);
```

