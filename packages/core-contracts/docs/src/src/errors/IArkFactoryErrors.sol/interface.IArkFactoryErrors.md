# IArkFactoryErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/errors/IArkFactoryErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the ArkFactory contract.*


## Errors
### CannotSetRaftToZeroAddress
Thrown when attempting to set the Raft address to the zero address.


```solidity
error CannotSetRaftToZeroAddress();
```

