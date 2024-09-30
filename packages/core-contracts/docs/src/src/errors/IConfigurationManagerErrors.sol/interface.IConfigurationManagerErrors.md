# IConfigurationManagerErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IConfigurationManagerErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the ConfigurationManager contract.*


## Errors
### ZeroAddress
Thrown when an operation is attempted with a zero address where a non-zero address is required.


```solidity
error ZeroAddress();
```

### ConfigurationManagerAlreadyInitialized
Thrown when ConfigurationManager was already initialized.


```solidity
error ConfigurationManagerAlreadyInitialized();
```

### RaftNotSet
Thrown when the Raft address is not set.


```solidity
error RaftNotSet();
```

### TipJarNotSet
Thrown when the TipJar address is not set.


```solidity
error TipJarNotSet();
```

### TreasuryNotSet
Thrown when the Treasury address is not set.


```solidity
error TreasuryNotSet();
```

### AddressZero
Thrown when constructor address is set to the zero address.


```solidity
error AddressZero();
```

