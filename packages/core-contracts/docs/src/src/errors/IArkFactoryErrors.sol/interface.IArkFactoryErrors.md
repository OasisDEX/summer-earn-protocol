# IArkFactoryErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IArkFactoryErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the ArkFactory contract.*


## Errors
### CannotSetRaftToZeroAddress
Thrown when attempting to set the Raft address to the zero address.


```solidity
error CannotSetRaftToZeroAddress();
```

