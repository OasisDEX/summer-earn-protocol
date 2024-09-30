# IPendleBaseArkErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/arks/IPendleBaseArkErrors.sol)


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

