# ICooldownEnforcer
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/utils/CooldownEnforcer/ICooldownEnforcer.sol)

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

