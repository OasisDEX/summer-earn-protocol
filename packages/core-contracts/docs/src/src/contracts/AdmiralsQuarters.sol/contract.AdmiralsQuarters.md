# AdmiralsQuarters
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/AdmiralsQuarters.sol)

**Inherits:**
Ownable, Multicall, ReentrancyGuardTransient, [IAdmiralsQuarters](/src/interfaces/IAdmiralsQuarters.sol/interface.IAdmiralsQuarters.md)

This contract uses an OpenZeppelin nonReentrant modifier with transient storage for gas efficiency.

When it was developed the OpenZeppelin version was 5.0.2 ( hence the use of locally stored
ReentrancyGuardTransient )

*A contract for managing deposits and withdrawals to/from FleetCommander contracts,
with integrated swapping functionality using 1inch Router.*

*How to use this contract:
1. Deposit tokens: Use `depositTokens` to deposit ERC20 tokens into the contract.
2. Withdraw tokens: Use `withdrawTokens` to withdraw deposited tokens.
3. Enter a fleet: Use `enterFleet` to deposit tokens into a FleetCommander contract.
4. Exit a fleet: Use `exitFleet` to withdraw tokens from a FleetCommander contract.
5. Swap tokens: Use `swap` to exchange one token for another using the 1inch Router.
6. Rescue tokens: Contract owner can use `rescueTokens` to withdraw any tokens stuck in the contract.*

*Multicall functionality:
This contract inherits from OpenZeppelin's Multicall, allowing multiple function calls to be batched into a single
transaction.
To use Multicall:
1. Encode each function call you want to make as calldata.
2. Pack these encoded function calls into an array of bytes.
3. Call the `multicall` function with this array as the argument.
Example Multicall usage:
bytes[] memory calls = new bytes[](2);
calls[0] = abi.encodeWithSelector(this.depositTokens.selector, tokenAddress, amount);
calls[1] = abi.encodeWithSelector(this.enterFleet.selector, fleetCommanderAddress, tokenAddress, amount);
(bool[] memory successes, bytes[] memory results) = this.multicall(calls);*

*Security considerations:
- All external functions are protected against reentrancy attacks.
- The contract uses OpenZeppelin's SafeERC20 for safe token transfers.
- Only the contract owner can rescue tokens.
- Ensure that the 1inch Router address provided in the constructor is correct and trusted.
- Since there is no data exchange between calls - make sure all the tokens are returned to the user*


## State Variables
### oneInchRouter

```solidity
address public immutable oneInchRouter;
```


## Functions
### constructor


```solidity
constructor(address _oneInchRouter) Ownable(msg.sender);
```

### depositTokens

Deposits tokens into the contract

*Emits a TokensDeposited event*


```solidity
function depositTokens(IERC20 asset, uint256 amount) external nonReentrant;
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
function withdrawTokens(IERC20 asset, uint256 amount) external nonReentrant;
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
function enterFleet(
    address fleetCommander,
    IERC20 inputToken,
    uint256 amount
)
    external
    nonReentrant
    returns (uint256 shares);
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
function exitFleet(address fleetCommander, uint256 amount) external nonReentrant returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander contract|
|`amount`|`uint256`|The amount of shares to withdraw (0 for all)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|assets The amount of assets received from the FleetCommander|


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
    nonReentrant
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


### _swap

*Internal function to perform a token swap using 1inch*


```solidity
function _swap(
    IERC20 fromToken,
    IERC20 toToken,
    uint256 amount,
    uint256 minTokensReceived,
    bytes calldata swapCalldata
)
    internal
    returns (uint256 swappedAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromToken`|`IERC20`|The token to swap from|
|`toToken`|`IERC20`|The token to swap to|
|`amount`|`uint256`|The amount of fromToken to swap|
|`minTokensReceived`|`uint256`|The minimum amount of toToken to receive after the swap|
|`swapCalldata`|`bytes`|The 1inch swap calldata|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`swappedAmount`|`uint256`|The amount of toToken received from the swap|


### rescueTokens

Allows the owner to rescue any ERC20 tokens sent to the contract by mistake

*Can only be called by the contract owner*


```solidity
function rescueTokens(IERC20 token, address to, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the ERC20 token to rescue|
|`to`|`address`|The address to send the rescued tokens to|
|`amount`|`uint256`|The amount of tokens to rescue|


