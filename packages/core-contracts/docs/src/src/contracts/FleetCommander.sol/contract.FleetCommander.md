# FleetCommander
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/FleetCommander.sol)

**Inherits:**
[IFleetCommander](/src/interfaces/IFleetCommander.sol/interface.IFleetCommander.md), ERC4626, [Tipper](/src/contracts/Tipper.sol/abstract.Tipper.md), [FleetCommanderConfigProvider](/src/contracts/FleetCommanderConfigProvider.sol/contract.FleetCommanderConfigProvider.md), [FleetCommanderCache](/src/contracts/FleetCommanderCache.sol/contract.FleetCommanderCache.md), [CooldownEnforcer](/src/utils/CooldownEnforcer/CooldownEnforcer.sol/abstract.CooldownEnforcer.md)


## State Variables
### DEFAULT_MAX_REBALANCE_OPERATIONS

```solidity
uint256 public constant DEFAULT_MAX_REBALANCE_OPERATIONS = 10;
```


## Functions
### constructor


```solidity
constructor(FleetCommanderParams memory params)
    ERC4626(IERC20(params.asset))
    ERC20(params.name, params.symbol)
    FleetCommanderConfigProvider(params)
    Tipper(params.configurationManager, params.initialTipRate)
    CooldownEnforcer(params.initialRebalanceCooldown, false);
```

### collectTip

*Modifier to collect the tip before any other action is taken*


```solidity
modifier collectTip();
```

### useDepositCache

This modifier retrieves ark data before the function execution,
allows the modified function to run, and then flushes the cache.

*Modifier to cache ark data for deposit operations.*

*The cache is required due to multiple calls to `totalAssets` in the same transaction.
those calls migh be gas expensive for some arks.*


```solidity
modifier useDepositCache();
```

### useWithdrawCache

This modifier retrieves withdrawable ark data before the function execution,
allows the modified function to run, and then flushes the cache.

*Modifier to cache withdrawable ark data for withdraw operations.*

*The cache is required due to multiple calls to `totalAssets` in the same transaction.
those calls migh be gas expensive for some arks.*


```solidity
modifier useWithdrawCache();
```

### withdrawFromBuffer


```solidity
function withdrawFromBuffer(uint256 assets, address receiver, address owner) public returns (uint256 shares);
```

### redeem

Redeems a specified amount of shares from the FleetCommander

*This function first attempts to redeem from the buffer. If the buffer doesn't have enough assets,
it will redeem from the arks. It also handles the case where the maximum possible amount is requested.*


```solidity
function redeem(
    uint256 shares,
    address receiver,
    address owner
)
    public
    override(ERC4626, IFleetCommander)
    collectTip
    useWithdrawCache
    returns (uint256 assets);
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


### redeemFromBuffer

Redeems shares for assets directly from the Buffer


```solidity
function redeemFromBuffer(
    uint256 shares,
    address receiver,
    address owner
)
    public
    collectTip
    useWithdrawCache
    returns (uint256 assets);
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


### withdraw

Withdraws a specified amount of assets from the FleetCommander

*This function first attempts to withdraw from the buffer. If the buffer doesn't have enough assets,
it will withdraw from the arks. It also handles the case where the maximum possible amount is requested.*


```solidity
function withdraw(
    uint256 assets,
    address receiver,
    address owner
)
    public
    override(ERC4626, IFleetCommander)
    collectTip
    useWithdrawCache
    returns (uint256 shares);
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


### withdrawFromArks

Forces a withdrawal of assets from the FleetCommander


```solidity
function withdrawFromArks(
    uint256 assets,
    address receiver,
    address owner
)
    public
    override(IFleetCommander)
    collectTip
    useWithdrawCache
    returns (uint256 totalSharesToRedeem);
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
|`totalSharesToRedeem`|`uint256`|shares The amount of shares redeemed|


### redeemFromArks

Redeems shares for assets from the FleetCommander


```solidity
function redeemFromArks(
    uint256 shares,
    address receiver,
    address owner
)
    public
    override(IFleetCommander)
    collectTip
    useWithdrawCache
    returns (uint256 totalAssetsToWithdraw);
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
|`totalAssetsToWithdraw`|`uint256`|assets The amount of assets forcefully withdrawn|


### deposit

Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.

*
- MUST emit the Deposit event.
- MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
deposit execution, and are accounted for during deposit.
- MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
approving enough underlying tokens to the Vault contract, etc).
NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.*


```solidity
function deposit(
    uint256 assets,
    address receiver
)
    public
    override(ERC4626, IERC4626)
    collectTip
    useDepositCache
    returns (uint256 shares);
```

### deposit

Deposits a specified amount of assets into the contract for a given receiver.


```solidity
function deposit(uint256 assets, address receiver, bytes memory referralCode) public returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to be deposited.|
|`receiver`|`address`|The address of the receiver who will receive the deposited assets.|
|`referralCode`|`bytes`|An optional referral code that can be used for tracking or rewards.|


### mint

Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.

*
- MUST emit the Deposit event.
- MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
execution, and are accounted for during mint.
- MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
approving enough underlying tokens to the Vault contract, etc).
NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.*


```solidity
function mint(
    uint256 shares,
    address receiver
)
    public
    override(ERC4626, IERC4626)
    collectTip
    useDepositCache
    returns (uint256 assets);
```

### tip

Accrues and distributes tips


```solidity
function tip() public returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The amount of tips accrued|


### totalAssets

Returns the total assets that are managed the FleetCommander.

*If cached data is available, it will be used. Otherwise, it will be calculated on demand (and cached)*


```solidity
function totalAssets() public view override(IFleetCommander, ERC4626) returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total amount of assets that can be withdrawn.|


### withdrawableTotalAssets

Returns the total assets that are currently withdrawable from the FleetCommander.

*If cached data is available, it will be used. Otherwise, it will be calculated on demand (and cached)*


```solidity
function withdrawableTotalAssets() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint256 The total amount of assets that can be withdrawn.|


### maxDeposit

Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
through a deposit call.

*
- MUST return a limited value if receiver is subject to some deposit limit.
- MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
- MUST NOT revert.*


```solidity
function maxDeposit(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxDeposit);
```

### maxMint

Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.

*
- MUST return a limited value if receiver is subject to some mint limit.
- MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
- MUST NOT revert.*


```solidity
function maxMint(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxMint);
```

### maxBufferWithdraw

Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
Vault, directly from Buffer.


```solidity
function maxBufferWithdraw(address owner) public view returns (uint256 _maxBufferWithdraw);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner of the assets|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_maxBufferWithdraw`|`uint256`|uint256 The maximum amount that can be withdrawn.|


### maxWithdraw

Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
Vault, through a withdraw call.

*
- MUST return a limited value if owner is subject to some withdrawal limit or timelock.
- MUST NOT revert.*


```solidity
function maxWithdraw(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxWithdraw);
```

### maxRedeem

Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
through a redeem call.

*
- MUST return a limited value if owner is subject to some withdrawal limit or timelock.
- MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
- MUST NOT revert.*


```solidity
function maxRedeem(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxRedeem);
```

### maxBufferRedeem

Returns the maximum amount of the underlying asset that can be redeemed from the owner balance in the
Vault, directly from Buffer.


```solidity
function maxBufferRedeem(address owner) public view returns (uint256 _maxBufferRedeem);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the owner of the assets|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_maxBufferRedeem`|`uint256`|uint256 The maximum amount that can be redeemed.|


### rebalance

Rebalances the assets across Arks

*RebalanceData struct contains:
- fromArk: The address of the Ark to move assets from
- toArk: The address of the Ark to move assets to
- amount: The amount of assets to move*


```solidity
function rebalance(RebalanceData[] calldata rebalanceData) external onlyKeeper enforceCooldown collectTip;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`||


### adjustBuffer

Adjusts the buffer of funds by moving assets between the buffer Ark and other Arks

*RebalanceData struct contains:
- fromArk: The address of the Ark to move assets from (must be buffer Ark for withdrawing from buffer)
- toArk: The address of the Ark to move assets to (must be buffer Ark for depositing to buffer)
- amount: The amount of assets to move*


```solidity
function adjustBuffer(RebalanceData[] calldata rebalanceData) external onlyKeeper enforceCooldown collectTip;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`||


### setTipJar

Sets a new tip jar address

*This function sets the tipJar address to the address specified in the configuration manager.*


```solidity
function setTipJar() external onlyGovernor;
```

### setTipRate

Sets a new tip rate for the FleetCommander

*Only callable by the governor*


```solidity
function setTipRate(Percentage newTipRate) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipRate`|`Percentage`|The new tip rate as a Percentage|


### updateRebalanceCooldown

Updates the rebalance cooldown period


```solidity
function updateRebalanceCooldown(uint256 newCooldown) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCooldown`|`uint256`|The new cooldown period in seconds|


### forceRebalance

Forces a rebalance operation

*has no cooldown enforced but only callable by privileged role*


```solidity
function forceRebalance(RebalanceData[] calldata rebalanceData) external onlyGovernor collectTip;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`||


### emergencyShutdown


```solidity
function emergencyShutdown() external onlyGovernor;
```

### transfer

Moves `amount` tokens from the caller's account to `to`.


```solidity
function transfer(address, uint256) public pure override(IERC20, ERC20) returns (bool);
```

### transferFrom

Moves `amount` tokens from `from` to `to` using the allowance mechanism.
`amount` is then deducted from the caller's allowance.


```solidity
function transferFrom(address, address, uint256) public pure override(IERC20, ERC20) returns (bool);
```

### _mintTip


```solidity
function _mintTip(address account, uint256 amount) internal virtual override;
```

### _reallocateAllAssets

Reallocates all assets based on the provided rebalance data


```solidity
function _reallocateAllAssets(RebalanceData[] calldata rebalanceData) internal returns (uint256 totalMoved);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`|Array of RebalanceData structs containing information about the reallocation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalMoved`|`uint256`|The total amount of assets moved during the reallocation|


### _board

Approves and boards a specified amount of assets to an Ark


```solidity
function _board(address ark, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`amount`|`uint256`|The amount of assets to board|


### _disembark

Disembarks a specified amount of assets from an Ark


```solidity
function _disembark(address ark, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`amount`|`uint256`|The amount of assets to disembark|


### _move

Moves a specified amount of assets from one Ark to another


```solidity
function _move(
    address fromArk,
    address toArk,
    uint256 amount,
    bytes memory boardData,
    bytes memory disembarkData
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromArk`|`address`|The address of the Ark to move assets from|
|`toArk`|`address`|The address of the Ark to move assets to|
|`amount`|`uint256`|The amount of assets to move|
|`boardData`|`bytes`|Additional data for the board operation|
|`disembarkData`|`bytes`|Additional data for the disembark operation|


### _reallocateAssets

Reallocates assets from one Ark to another

*This function handles the reallocation of assets between Arks, considering:
1. The maximum allocation of the destination Ark
2. The current allocation of the destination Ark*


```solidity
function _reallocateAssets(RebalanceData memory data) internal returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`RebalanceData`|The RebalanceData struct containing information about the reallocation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|uint256 The actual amount of assets reallocated|


### _forceDisembarkFromSortedArks

Withdraws assets from multiple arks in a specific order

*This function attempts to withdraw the requested amount from arks,
that allow such operations, in the order of total assets held*


```solidity
function _forceDisembarkFromSortedArks(uint256 assets) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The total amount of assets to withdraw|


### _validateAdjustBuffer

Validates the data for adjusting the buffer

*This function checks if all operations in the rebalance data are consistent
(either all moving to buffer or all moving from buffer) and ensures that
the buffer balance remains above the minimum required balance*


```solidity
function _validateAdjustBuffer(RebalanceData[] calldata rebalanceData) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`|An array of RebalanceData structs containing the rebalance operations|


### _validateRebalance

Validates the rebalance operations to ensure they meet all required constraints

*This function performs a series of checks on each rebalance operation:
1. Ensures general reallocation constraints are met
2. Verifies the buffer ark is not directly involved in rebalancing*


```solidity
function _validateRebalance(RebalanceData[] calldata rebalanceData) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`|An array of RebalanceData structs, each representing a rebalance operation|


### _validateBufferArkNotInvolved

Validates that the buffer ark is not directly involved in a rebalance operation

*This function checks if either the source or destination ark in a rebalance operation is the buffer ark*


```solidity
function _validateBufferArkNotInvolved(RebalanceData memory data) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`RebalanceData`|The RebalanceData struct containing the source and destination ark addresses|


### _validateReallocateAllAssets

Validates the asset reallocation data for correctness and consistency

*This function checks various conditions of the rebalance operations:
- Number of operations is within limits
- Each operation has valid amounts and addresses
- Arks involved in the operations are active and have proper allocations*


```solidity
function _validateReallocateAllAssets(RebalanceData[] calldata rebalanceData) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rebalanceData`|`RebalanceData[]`|An array of RebalanceData structs containing the rebalance operations|


### _validateReallocateAssets

Validates the reallocation of assets between two ARKs.


```solidity
function _validateReallocateAssets(address fromArk, address toArk, uint256 amount) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromArk`|`address`|The address of the source ARK.|
|`toArk`|`address`|The address of the destination ARK.|
|`amount`|`uint256`|The amount of assets to be reallocated.|


### _validateBufferWithdraw

Validates the withdraw request

*This function checks two conditions:
1. The caller is authorized to withdraw on behalf of the owner
2. The withdrawal amount does not exceed the maximum allowed*


```solidity
function _validateBufferWithdraw(uint256 assets, uint256 shares, address owner) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to withdraw|
|`shares`|`uint256`|The number of shares to redeem|
|`owner`|`address`|The address of the owner of the assets|


### _validateBufferRedeem

Validates the redemption request

*This function checks two conditions:
1. The caller is authorized to redeem on behalf of the owner
2. The redemption amount does not exceed the maximum allowed*


```solidity
function _validateBufferRedeem(uint256 shares, address owner) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares to redeem|
|`owner`|`address`|The address of the owner of the shares|


### _validateDeposit

Validates the deposit request

*This function checks if the requested deposit amount exceeds the maximum allowed*


```solidity
function _validateDeposit(uint256 assets, address owner) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to deposit|
|`owner`|`address`|The address of the account making the deposit|


### _validateMint

Validates the mint request

*This function checks if the requested mint amount exceeds the maximum allowed*


```solidity
function _validateMint(uint256 shares, address owner) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The number of shares to mint|
|`owner`|`address`|The address of the account minting the shares|


### _validateWithdrawFromArks

Validates the force withdraw request

*This function checks two conditions:
1. The caller is authorized to withdraw on behalf of the owner
2. The withdrawal amount does not exceed the maximum allowed*


```solidity
function _validateWithdrawFromArks(uint256 assets, uint256 shares, address owner) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to withdraw|
|`shares`|`uint256`|The amount of shares to redeem|
|`owner`|`address`|The address of the owner of the assets|


### _validateForceRedeem

Validates the force redeem request

*This function checks two conditions:
1. The caller is authorized to redeem on behalf of the owner
2. The redemption amount does not exceed the maximum allowed*


```solidity
function _validateForceRedeem(uint256 shares, address owner) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares to redeem|
|`owner`|`address`|The address of the owner of the assets|


