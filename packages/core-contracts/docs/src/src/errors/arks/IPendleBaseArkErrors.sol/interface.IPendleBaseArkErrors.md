# IPendleBaseArkErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/errors/arks/IPendleBaseArkErrors.sol)


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

