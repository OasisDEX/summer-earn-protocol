# ITipJarEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/events/ITipJarEvents.sol)

Interface for events emitted by the TipJar contract


## Events
### TipStreamAdded
Emitted when a new tip stream is added to the TipJar


```solidity
event TipStreamAdded(address indexed recipient, Percentage allocation, uint256 lockedUntilEpoch);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the recipient for the new tip stream|
|`allocation`|`Percentage`|The allocation percentage for the new tip stream|
|`lockedUntilEpoch`|`uint256`|The minimum duration (as a UNIX timestamp) during which this tip stream cannot be modified or removed|

### TipStreamRemoved
Emitted when a tip stream is removed from the TipJar


```solidity
event TipStreamRemoved(address indexed recipient);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the recipient whose tip stream was removed|

### TipStreamUpdated
Emitted when an existing tip stream is updated


```solidity
event TipStreamUpdated(address indexed recipient, Percentage newAllocation, uint256 newLockedUntilEpoch);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the recipient whose tip stream was updated|
|`newAllocation`|`Percentage`|The new allocation percentage for the tip stream|
|`newLockedUntilEpoch`|`uint256`|The new minimum duration (as a UNIX timestamp) during which this tip stream cannot be modified or removed|

### TipJarShaken
Emitted when the TipJar distributes collected tips from a FleetCommander


```solidity
event TipJarShaken(address indexed fleetCommander, uint256 totalDistributed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander contract from which tips were distributed|
|`totalDistributed`|`uint256`|The total amount of underlying assets distributed to all recipients|

