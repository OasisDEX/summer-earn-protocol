# IFleetCommander
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/IFleetCommander.sol)

**Inherits:**
IERC4626, [IFleetCommanderEvents](/src/events/IFleetCommanderEvents.sol/interface.IFleetCommanderEvents.md), [IFleetCommanderErrors](/src/errors/IFleetCommanderErrors.sol/interface.IFleetCommanderErrors.md), [IFleetCommanderConfigProvider](/src/interfaces/IFleetCommanderConfigProvider.sol/interface.IFleetCommanderConfigProvider.md)

Interface for the FleetCommander contract, which manages asset allocation across multiple Arks


## Functions
### withdrawableTotalAssets

Returns the total assets that are currently withdrawable from the FleetCommander.

*If cached data is available, it will be used. Otherwise, it will be calculated on demand (and cached)*


```solidity
function withdrawableTotalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total amount of assets that can be withdrawn.|


### totalAssets

Returns the total assets that are managed the FleetCommander.

*If cached data is available, it will be used. Otherwise, it will be calculated on demand (and cached)*


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total amount of assets that can be withdrawn.|


### maxBufferWithdraw

Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
Vault, directly from Buffer.


```solidity
function maxBufferWithdraw(address owner) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner of the assets|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The maximum amount that can be withdrawn.|


### maxBufferRedeem

Returns the maximum amount of the underlying asset that can be redeemed from the owner balance in the
Vault, directly from Buffer.


```solidity
function maxBufferRedeem(address owner) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner of the assets|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The maximum amount that can be redeemed.|


### deposit

Deposits a specified amount of assets into the contract for a given receiver.


```solidity
function deposit(uint256 assets, address receiver, bytes memory referralCode) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to be deposited.|
|`receiver`|`address`|The address of the receiver who will receive the deposited assets.|
|`referralCode`|`bytes`|An optional referral code that can be used for tracking or rewards.|


### withdrawFromArks

Forces a withdrawal of assets from the FleetCommander


```solidity
function withdrawFromArks(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to forcefully withdraw|
|`receiver`|`address`|The address that will receive the withdrawn assets|
|`owner`|`address`|The address of the owner of the assets|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares redeemed|


### withdraw

Withdraws a specified amount of assets from the FleetCommander

*This function first attempts to withdraw from the buffer. If the buffer doesn't have enough assets,
it will withdraw from the arks. It also handles the case where the maximum possible amount is requested.*


```solidity
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to withdraw. If set to type(uint256).max, it will withdraw the maximum possible amount.|
|`receiver`|`address`|The address that will receive the withdrawn assets|
|`owner`|`address`|The address of the owner of the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares burned in exchange for the withdrawn assets|


### redeem

Redeems a specified amount of shares from the FleetCommander

*This function first attempts to redeem from the buffer. If the buffer doesn't have enough assets,
it will redeem from the arks. It also handles the case where the maximum possible amount is requested.*


```solidity
function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares to redeem. If set to type(uint256).max, it will redeem all shares owned by the owner.|
|`receiver`|`address`|The address that will receive the redeemed assets|
|`owner`|`address`|The address of the owner of the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets received in exchange for the redeemed shares|


### redeemFromArks

Redeems shares for assets from the FleetCommander


```solidity
function redeemFromArks(uint256 shares, address receiver, address owner) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares to redeem|
|`receiver`|`address`| The address that will receive the assets|
|`owner`|`address`|The address of the owner of the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets forcefully withdrawn|


### redeemFromBuffer

Redeems shares for assets directly from the Buffer


```solidity
function redeemFromBuffer(uint256 shares, address receiver, address owner) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares to redeem|
|`receiver`|`address`|The address that will receive the assets|
|`owner`|`address`|The address of the owner of the shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets redeemed|


### withdrawFromBuffer

Forces a withdrawal of assets directly from the Buffer


```solidity
function withdrawFromBuffer(uint256 assets, address receiver, address owner) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to withdraw|
|`receiver`|`address`|The address that will receive the withdrawn assets|
|`owner`|`address`|The address of the owner of the assets|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares redeemed|


### tip

Accrues and distributes tips


```solidity
function tip() external returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The amount of tips accrued|


### rebalance

Rebalances the assets across Arks

*RebalanceData struct contains:
- fromArk: The address of the Ark to move assets from
- toArk: The address of the Ark to move assets to
- amount: The amount of assets to move*

*Using type(uint256).max as the amount will move all assets from the fromArk to the toArk*

*Rebalance operations cannot involve the buffer Ark directly*

*The number of operations in a single rebalance call is limited to MAX_REBALANCE_OPERATIONS*

*Rebalance is subject to a cooldown period between calls*

*Only callable by accounts with the Keeper role*


```solidity
function rebalance(RebalanceData[] calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`RebalanceData[]`|Array of RebalanceData structs|


### adjustBuffer

Adjusts the buffer of funds by moving assets between the buffer Ark and other Arks

*RebalanceData struct contains:
- fromArk: The address of the Ark to move assets from (must be buffer Ark for withdrawing from buffer)
- toArk: The address of the Ark to move assets to (must be buffer Ark for depositing to buffer)
- amount: The amount of assets to move*

*Unlike rebalance, adjustBuffer operations must involve the buffer Ark*

*All operations in a single adjustBuffer call must be in the same direction (either all to buffer or all from
buffer)*

*type(uint256).max is not allowed as an amount for buffer adjustments*

*When withdrawing from the buffer, the total amount moved cannot reduce the buffer balance below
minFundsBufferBalance*

*The number of operations in a single adjustBuffer call is limited to MAX_REBALANCE_OPERATIONS*

*AdjustBuffer is subject to a cooldown period between calls*

*Only callable by accounts with the Keeper role*


```solidity
function adjustBuffer(RebalanceData[] calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`RebalanceData[]`|Array of RebalanceData structs|


### setTipJar

Sets a new tip jar address

*This function sets the tipJar address to the address specified in the configuration manager.*


```solidity
function setTipJar() external;
```

### setTipRate

Sets a new tip rate for the FleetCommander

*Only callable by the governor*

*The tip rate is set as a Percentage. Percentages use 18 decimals of precision
For example, for a 5% rate, you'd pass 5 * 1e18 (5 000 000 000 000 000 000)*


```solidity
function setTipRate(Percentage newTipRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipRate`|`Percentage`|The new tip rate as a Percentage|


### updateRebalanceCooldown

Updates the rebalance cooldown period


```solidity
function updateRebalanceCooldown(uint256 newCooldown) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCooldown`|`uint256`|The new cooldown period in seconds|


### forceRebalance

Forces a rebalance operation

*has no cooldown enforced but only callable by privileged role*


```solidity
function forceRebalance(RebalanceData[] calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`RebalanceData[]`|Array of typed rebalance data struct|


### emergencyShutdown

Initiates an emergency shutdown of the FleetCommander

*This action can only be performed under critical circumstances and typically by governance or a privileged
role.*


```solidity
function emergencyShutdown() external;
```

