# IPendleBaseArkEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/events/arks/IPendleBaseArkEvents.sol)

Interface for events emitted by Pendle Ark contracts

*This interface defines events related to market rollovers, slippage updates, and oracle duration changes*


## Events
### MarketRolledOver
Emitted when the Pendle market is rolled over to a new market

*This event is triggered during the rollover process when the current market expires*


```solidity
event MarketRolledOver(address indexed newMarket);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMarket`|`address`|The address of the new Pendle market after rollover|

### SlippageUpdated
Emitted when the slippage tolerance is updated

*This event is triggered when the governor changes the slippage settings*


```solidity
event SlippageUpdated(Percentage newSlippagePercentage);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newSlippagePercentage`|`Percentage`|The new slippage tolerance represented as a Percentage|

### OracleDurationUpdated
Emitted when the oracle duration is updated

*This event is triggered when the governor changes the oracle duration settings*


```solidity
event OracleDurationUpdated(uint32 newOracleDuration);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOracleDuration`|`uint32`|The new oracle duration in seconds|

