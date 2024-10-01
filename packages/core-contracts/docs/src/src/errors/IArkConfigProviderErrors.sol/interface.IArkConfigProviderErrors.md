# IArkConfigProviderErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/errors/IArkConfigProviderErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the ArkConfigProvider contract.*


## Errors
### CannotDeployArkWithoutConfigurationManager
Thrown when attempting to deploy an Ark without specifying a configuration manager.


```solidity
error CannotDeployArkWithoutConfigurationManager();
```

### CannotDeployArkWithoutRaft
Thrown when attempting to deploy an Ark without specifying a Raft address.


```solidity
error CannotDeployArkWithoutRaft();
```

### CannotDeployArkWithoutToken
Thrown when attempting to deploy an Ark without specifying a token address.


```solidity
error CannotDeployArkWithoutToken();
```

### CannotDeployArkWithEmptyName
Thrown when attempting to deploy an Ark with an empty name.


```solidity
error CannotDeployArkWithEmptyName();
```

### InvalidVaultAddress
Thrown when an invalid vault address is provided.


```solidity
error InvalidVaultAddress();
```

### ERC4626AssetMismatch
Thrown when there's a mismatch between expected and actual assets in an ERC4626 operation.


```solidity
error ERC4626AssetMismatch();
```

