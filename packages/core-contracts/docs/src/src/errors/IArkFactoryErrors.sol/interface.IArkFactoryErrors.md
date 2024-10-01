# IArkFactoryErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/errors/IArkFactoryErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the ArkFactory contract.*


## Errors
### CannotSetRaftToZeroAddress
Thrown when attempting to set the Raft address to the zero address.


```solidity
error CannotSetRaftToZeroAddress();
```

