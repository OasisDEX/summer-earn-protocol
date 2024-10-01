# IPendleBaseArkErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/errors/arks/IPendleBaseArkErrors.sol)


## Errors
### OracleNotReady

```solidity
error OracleNotReady();
```

### InvalidAssetForSY

```solidity
error InvalidAssetForSY();
```

### InvalidNextMarket

```solidity
error InvalidNextMarket();
```

### OracleDurationTooLow

```solidity
error OracleDurationTooLow(uint32 providedDuration, uint256 minimumDuration);
```

### SlippagePercentageTooHigh

```solidity
error SlippagePercentageTooHigh(Percentage providedSlippage, Percentage maxSlippage);
```

### MarketExpired

```solidity
error MarketExpired();
```

