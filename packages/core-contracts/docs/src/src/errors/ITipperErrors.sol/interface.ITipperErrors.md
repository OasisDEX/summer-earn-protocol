# ITipperErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/errors/ITipperErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the Tipper contract.*


## Errors
### InvalidFleetCommanderAddress
Thrown when an invalid FleetCommander address is provided.


```solidity
error InvalidFleetCommanderAddress();
```

### InvalidTipJarAddress
Thrown when an invalid TipJar address is provided.


```solidity
error InvalidTipJarAddress();
```

### TipRateCannotExceedOneHundredPercent
Thrown when the tip rate exceeds 100%.


```solidity
error TipRateCannotExceedOneHundredPercent();
```

