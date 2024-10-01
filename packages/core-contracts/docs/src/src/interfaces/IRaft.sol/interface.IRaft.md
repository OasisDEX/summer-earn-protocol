# IRaft
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/IRaft.sol)

**Inherits:**
[IRaftEvents](/src/events/IRaftEvents.sol/interface.IRaftEvents.md), [IRaftErrors](/src/errors/IRaftErrors.sol/interface.IRaftErrors.md)

Interface for the Raft contract which manages harvesting, auctioning, and reinvesting of rewards.

*This interface defines the core functionality for managing rewards from various Arks.*


## Functions
### harvest

Harvests rewards from the specified Ark without auctioning or reinvesting.

*This function only collects rewards, storing them in the Raft contract for later use.*


```solidity
function harvest(address ark, bytes calldata extraHarvestData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract to harvest rewards from.|
|`extraHarvestData`|`bytes`|Additional data required by a protocol to harvest|


### sweep

Sweeps tokens from the specified Ark and returns them to the caller.

*This function is used to retrieve any excess tokens from the Ark that are not needed for further operations.*


```solidity
function sweep(
    address ark,
    address[] calldata tokens
)
    external
    returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract to sweep tokens from.|
|`tokens`|`address[]`|The addresses of the tokens to sweep.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sweptTokens`|`address[]`|The addresses of the tokens that were swept.|
|`sweptAmounts`|`uint256[]`|The amounts of the tokens that were swept.|


### sweepAndStartAuction

Sweeps tokens from the specified Ark and starts an auction for them.

*This function is used to handle excess tokens from the Ark that are not needed for further operations.*


```solidity
function sweepAndStartAuction(address ark, address[] calldata tokens, address paymentToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract to sweep tokens from.|
|`tokens`|`address[]`|The addresses of the tokens to sweep.|
|`paymentToken`|`address`|The address of the token used for payment in the auction.|


### getObtainedTokens

Retrieves the amount of harvested rewards for a specific Ark and reward token.

*This function allows querying the balance of harvested rewards before deciding on further actions.*


```solidity
function getObtainedTokens(address ark, address rewardToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract.|
|`rewardToken`|`address`|The address of the reward token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of harvested rewards for the specified Ark and token.|


### startAuction

Starts a Dutch auction for the harvested rewards of a specific Ark and reward token.

*This function initiates the auction process for selling harvested rewards.*


```solidity
function startAuction(address ark, address rewardToken, address paymentToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract.|
|`rewardToken`|`address`|The address of the reward token to be auctioned.|
|`paymentToken`|`address`|The address of the token used for payment in the auction.|


### buyTokens

Allows users to buy tokens from an active auction.

*This function handles the token purchase process in the Dutch auction.*


```solidity
function buyTokens(address ark, address rewardToken, uint256 amount) external returns (uint256 paymentAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract.|
|`rewardToken`|`address`|The address of the reward token being auctioned.|
|`amount`|`uint256`|The amount of tokens to purchase.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`paymentAmount`|`uint256`|The amount of payment tokens required to purchase the specified amount of reward tokens.|


### finalizeAuction

Finalizes an auction after its end time has been reached.

*This function settles the auction and handles unsold tokens.*


```solidity
function finalizeAuction(address ark, address rewardToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract.|
|`rewardToken`|`address`|The address of the reward token that was auctioned.|


### getCurrentPrice

*Returns the current price of a given asset in terms of the reward token.*


```solidity
function getCurrentPrice(address ark, address rewardToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the asset.|
|`rewardToken`|`address`|The address of the reward token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price of the asset.|


### board

Boards the auctioned token to an Ark

*This function board tokens to ark that requires additioan data for boarding process.*

*can only be called by governance*


```solidity
function board(address ark, address rewardToken, bytes calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract.|
|`rewardToken`|`address`|The address of the reward token to board the rewards to.|
|`data`|`bytes`|Additional data required by the Ark to board rewards.|


