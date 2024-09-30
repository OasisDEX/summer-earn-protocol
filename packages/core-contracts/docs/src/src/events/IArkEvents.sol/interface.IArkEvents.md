# IArkEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/IArkEvents.sol)

Interface for events emitted by Ark contracts


## Events
### ArkHarvested
Emitted when rewards are harvested from an Ark


```solidity
event ArkHarvested(address[] indexed rewardTokens, uint256[] indexed rewardAmounts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|The addresses of the harvested reward tokens|
|`rewardAmounts`|`uint256[]`|The amounts of the harvested reward tokens|

### Boarded
Emitted when tokens are boarded (deposited) into the Ark


```solidity
event Boarded(address indexed commander, address token, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`commander`|`address`|The address of the FleetCommander initiating the boarding|
|`token`|`address`|The address of the token being boarded|
|`amount`|`uint256`|The amount of tokens boarded|

### Disembarked
Emitted when tokens are disembarked (withdrawn) from the Ark


```solidity
event Disembarked(address indexed commander, address token, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`commander`|`address`|The address of the FleetCommander initiating the disembarking|
|`token`|`address`|The address of the token being disembarked|
|`amount`|`uint256`|The amount of tokens disembarked|

### Moved
Emitted when tokens are moved from one address to another


```solidity
event Moved(address indexed from, address indexed to, address token, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Ark being boarded from|
|`to`|`address`|Ark being boarded to|
|`token`|`address`|The address of the token being moved|
|`amount`|`uint256`|The amount of tokens moved|

### ArkPoked
Emitted when the Ark is poked and the share price is updated


```solidity
event ArkPoked(uint256 currentPrice, uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`currentPrice`|`uint256`|Current share price of the Ark|
|`timestamp`|`uint256`|The timestamp of the poke|

### ArkSwept
Emitted when the Ark is swept


```solidity
event ArkSwept(address[] indexed sweptTokens, uint256[] indexed sweptAmounts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sweptTokens`|`address[]`|The addresses of the swept tokens|
|`sweptAmounts`|`uint256[]`|The amounts of the swept tokens|

