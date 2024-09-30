# IAccessControlErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IAccessControlErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for access control in the system.*


## Errors
### CallerIsNotGovernor
Thrown when a caller is not the governor.


```solidity
error CallerIsNotGovernor(address caller);
```

### CallerIsNotKeeper
Thrown when a caller is not a keeper.


```solidity
error CallerIsNotKeeper(address caller);
```

### CallerIsNotSuperKeeper
Thrown when a caller is not a super keeper.


```solidity
error CallerIsNotSuperKeeper(address caller);
```

### CallerIsNotCommander
Thrown when a caller is not the commander.


```solidity
error CallerIsNotCommander(address caller);
```

### CallerIsNotRaftOrCommander
Thrown when a caller is neither the Raft nor the commander.


```solidity
error CallerIsNotRaftOrCommander(address caller);
```

### CallerIsNotRaft
Thrown when a caller is not the Raft.


```solidity
error CallerIsNotRaft(address caller);
```

### CallerIsNotAdmin
Thrown when a caller is not an admin.


```solidity
error CallerIsNotAdmin(address caller);
```

### CallerIsNotAuthorizedToBoard
Thrown when a caller is not authorized to board.


```solidity
error CallerIsNotAuthorizedToBoard(address caller);
```

### DirectGrantIsDisabled
Thrown when direct grant is disabled.


```solidity
error DirectGrantIsDisabled(address caller);
```

### DirectRevokeIsDisabled
Thrown when direct revoke is disabled.


```solidity
error DirectRevokeIsDisabled(address caller);
```

### InvalidAccessManagerAddress
Thrown when an invalid access manager address is provided.


```solidity
error InvalidAccessManagerAddress(address invalidAddress);
```

