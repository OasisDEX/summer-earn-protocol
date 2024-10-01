# IAdmiralsQuarters
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/IAdmiralsQuarters.sol)

**Inherits:**
[IAdmiralsQuartersEvents](/src/events/IAdmiralsQuartersEvents.sol/interface.IAdmiralsQuartersEvents.md), [IAdmiralsQuartersErrors](/src/errors/IAdmiralsQuartersErrors.sol/interface.IAdmiralsQuartersErrors.md)

Interface for the AdmiralsQuarters contract, which manages interactions with FleetCommanders and token swaps


## Functions
### oneInchRouter

Returns the address of the 1inch router used for token swaps


```solidity
function oneInchRouter() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the 1inch router|


### depositTokens

Deposits tokens into the contract

*Emits a TokensDeposited event*


```solidity
function depositTokens(IERC20 asset, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`IERC20`|The token to be deposited|
|`amount`|`uint256`|The amount of tokens to deposit|


### withdrawTokens

Withdraws tokens from the contract

*Emits a TokensWithdrawn event*


```solidity
function withdrawTokens(IERC20 asset, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`IERC20`|The token to be withdrawn|
|`amount`|`uint256`|The amount of tokens to withdraw (0 for all)|


### enterFleet

Enters a FleetCommander by depositing tokens

*Emits a FleetEntered event*


```solidity
function enterFleet(address fleetCommander, IERC20 inputToken, uint256 amount) external returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander contract|
|`inputToken`|`IERC20`|The token to be deposited|
|`amount`|`uint256`|The amount of inputToken to be deposited (0 for all)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares received from the FleetCommander|


### exitFleet

Exits a FleetCommander by withdrawing tokens

*Emits a FleetExited event*


```solidity
function exitFleet(address fleetCommander, uint256 amount) external returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander contract|
|`amount`|`uint256`|The amount of shares to withdraw (0 for all)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets received from the FleetCommander|


### swap

Performs a token swap using 1inch Router

*Emits a Swapped event*


```solidity
function swap(
    IERC20 fromToken,
    IERC20 toToken,
    uint256 amount,
    uint256 minTokensReceived,
    bytes calldata swapCalldata
)
    external
    returns (uint256 swappedAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromToken`|`IERC20`|The token to swap from|
|`toToken`|`IERC20`|The token to swap to|
|`amount`|`uint256`|The amount of fromToken to swap|
|`minTokensReceived`|`uint256`|The minimum amount of toToken to receive after the swap|
|`swapCalldata`|`bytes`|The calldata for the 1inch swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`swappedAmount`|`uint256`|The amount of toToken received after the swap|


### rescueTokens

Allows the owner to rescue any ERC20 tokens sent to the contract by mistake

*Can only be called by the contract owner*

*Emits a TokensRescued event*


```solidity
function rescueTokens(IERC20 token, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the ERC20 token to rescue|
|`to`|`address`|The address to send the rescued tokens to|
|`amount`|`uint256`|The amount of tokens to rescue|


