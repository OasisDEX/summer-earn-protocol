# IAdmiralsQuartersErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/errors/IAdmiralsQuartersErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the AdmiralsQuarters contract.*


## Errors
### SwapFailed
Thrown when a swap operation fails.


```solidity
error SwapFailed();
```

### AssetMismatch
Thrown when there's a mismatch between expected and actual assets in an operation.


```solidity
error AssetMismatch();
```

### InsufficientOutputAmount
Thrown when the output amount from an operation is less than the expected minimum.


```solidity
error InsufficientOutputAmount();
```

### InvalidFleetCommander
Thrown when an invalid FleetCommander address is provided or used.


```solidity
error InvalidFleetCommander();
```

### InvalidToken
Thrown when an invalid token address is provided or used.


```solidity
error InvalidToken();
```

### UnsupportedSwapFunction
Thrown when an unsupported swap function is called or referenced.


```solidity
error UnsupportedSwapFunction();
```

### SwapAmountMismatch
Thrown when there's a mismatch between expected and actual swap amounts.


```solidity
error SwapAmountMismatch();
```

### ReentrancyGuard
Thrown when a reentrancy attempt is detected.


```solidity
error ReentrancyGuard();
```

### ZeroAmount
Thrown when an operation is attempted with a zero amount where a non-zero amount is required.


```solidity
error ZeroAmount();
```

### InvalidRouterAddress
Thrown when an invalid router address is provided or used.


```solidity
error InvalidRouterAddress();
```

