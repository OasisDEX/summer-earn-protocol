# IFleetCommanderEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/events/IFleetCommanderEvents.sol)


## Events
### Rebalanced
Emitted when a rebalance operation is completed


```solidity
event Rebalanced(address indexed keeper, RebalanceData[] rebalances);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keeper`|`address`|The address of the keeper who initiated the rebalance|
|`rebalances`|`RebalanceData[]`|An array of RebalanceData structs detailing the rebalance operations|

### QueuedFundsCommitted
Emitted when queued funds are committed


```solidity
event QueuedFundsCommitted(address indexed keeper, uint256 prevBalance, uint256 newBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keeper`|`address`|The address of the keeper who committed the funds|
|`prevBalance`|`uint256`|The previous balance before committing funds|
|`newBalance`|`uint256`|The new balance after committing funds|

### FundsQueueRefilled
Emitted when the funds queue is refilled


```solidity
event FundsQueueRefilled(address indexed keeper, uint256 prevBalance, uint256 newBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keeper`|`address`|The address of the keeper who initiated the queue refill|
|`prevBalance`|`uint256`|The previous balance before refilling|
|`newBalance`|`uint256`|The new balance after refilling|

### MinFundsQueueBalanceUpdated
Emitted when the minimum balance of the funds queue is updated


```solidity
event MinFundsQueueBalanceUpdated(address indexed keeper, uint256 newBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keeper`|`address`|The address of the keeper who updated the minimum balance|
|`newBalance`|`uint256`|The new minimum balance|

### FeeAddressUpdated
Emitted when the fee address is updated


```solidity
event FeeAddressUpdated(address newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAddress`|`address`|The new fee address|

### FundsBufferBalanceUpdated
Emitted when the funds buffer balance is updated


```solidity
event FundsBufferBalanceUpdated(address indexed user, uint256 prevBalance, uint256 newBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who triggered the update|
|`prevBalance`|`uint256`|The previous buffer balance|
|`newBalance`|`uint256`|The new buffer balance|

### FleetCommanderBufferAdjusted

```solidity
event FleetCommanderBufferAdjusted(address indexed keeper, uint256 totalMoved);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keeper`|`address`|Keeper address|
|`totalMoved`|`uint256`|Total amount of funds moved to arks|

### FleetCommanderWithdrawnFromArks
Emitted when funds are withdrawn from Arks


```solidity
event FleetCommanderWithdrawnFromArks(address indexed owner, address receiver, uint256 totalWithdrawn);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner who initiated the withdrawal|
|`receiver`|`address`|The address of the receiver of the withdrawn funds|
|`totalWithdrawn`|`uint256`|The total amount of funds withdrawn|

### FleetCommanderRedeemedFromArks
Emitted when funds are redeemed from Arks


```solidity
event FleetCommanderRedeemedFromArks(address indexed owner, address receiver, uint256 totalRedeemed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner who initiated the redemption|
|`receiver`|`address`|The address of the receiver of the redeemed funds|
|`totalRedeemed`|`uint256`|The total amount of funds redeemed|

### FleetCommanderReferral
Emitted when referee deposits into the FleetCommander


```solidity
event FleetCommanderReferral(address indexed referee, bytes indexed referralCode);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`referee`|`address`|The address of the referee who was referred|
|`referralCode`|`bytes`|The referral code of the referrer|

