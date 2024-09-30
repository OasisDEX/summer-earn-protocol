# IArkErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IArkErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the Ark contract.*


## Errors
### CannotRemoveCommanderFromArkWithAssets
Thrown when attempting to remove a commander from an Ark that still has assets.


```solidity
error CannotRemoveCommanderFromArkWithAssets();
```

### CannotAddCommanderToArkWithCommander
Thrown when trying to add a commander to an Ark that already has one.


```solidity
error CannotAddCommanderToArkWithCommander();
```

### CannotUseKeeperDataWhenNotRequired
Thrown when attempting to use keeper data when it's not required.


```solidity
error CannotUseKeeperDataWhenNotRequired();
```

### KeeperDataRequired
Thrown when keeper data is required but not provided.


```solidity
error KeeperDataRequired();
```

### InvalidBoardData
Thrown when invalid board data is provided.


```solidity
error InvalidBoardData();
```

### InvalidDisembarkData
Thrown when invalid disembark data is provided.


```solidity
error InvalidDisembarkData();
```

