# FleetCommander
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/FleetCommander.sol)

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


```solidity
function redeem(
    uint256 shares,
    address receiver,
    address owner
)
    public
    override(ERC4626, IERC4626)
    collectTip
    useWithdrawCache
    returns (uint256 assets);
```

### redeemFromBuffer


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

### withdraw


```solidity
function withdraw(
    uint256 assets,
    address receiver,
    address owner
)
    public
    override(ERC4626, IERC4626)
    collectTip
    useWithdrawCache
    returns (uint256 shares);
```

### withdrawFromArks


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

### redeemFromArks


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

### deposit


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


```solidity
function deposit(uint256 assets, address receiver, bytes memory referralCode) public returns (uint256);
```

### mint


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


```solidity
function tip() public returns (uint256);
```

### totalAssets


```solidity
function totalAssets() public view override(ERC4626, IERC4626) returns (uint256);
```

### withdrawableTotalAssets


```solidity
function withdrawableTotalAssets() public view returns (uint256);
```

### maxDeposit


```solidity
function maxDeposit(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxDeposit);
```

### maxMint


```solidity
function maxMint(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxMint);
```

### maxBufferWithdraw


```solidity
function maxBufferWithdraw(address owner) public view returns (uint256 _maxBufferWithdraw);
```

### maxWithdraw


```solidity
function maxWithdraw(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxWithdraw);
```

### maxRedeem


```solidity
function maxRedeem(address owner) public view override(ERC4626, IERC4626) returns (uint256 _maxRedeem);
```

### maxBufferRedeem


```solidity
function maxBufferRedeem(address owner) public view returns (uint256 _maxBufferRedeem);
```

### rebalance


```solidity
function rebalance(RebalanceData[] calldata rebalanceData) external onlyKeeper enforceCooldown collectTip;
```

### adjustBuffer


```solidity
function adjustBuffer(RebalanceData[] calldata rebalanceData) external onlyKeeper enforceCooldown collectTip;
```

### setTipJar


```solidity
function setTipJar() external onlyGovernor;
```

### setTipRate

Sets a new tip rate for the protocol

*Only callable by the governor*

*The tip rate is set as a Percentage. Percentages use 18 decimals of precision
For example, for a 5% rate, you'd pass 5 * 1e18 (5 000 000 000 000 000 000)*


```solidity
function setTipRate(Percentage newTipRate) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipRate`|`Percentage`|The new tip rate as a Percentage|


### updateRebalanceCooldown


```solidity
function updateRebalanceCooldown(uint256 newCooldown) external onlyGovernor;
```

### forceRebalance


```solidity
function forceRebalance(RebalanceData[] calldata rebalanceData) external onlyGovernor collectTip;
```

### emergencyShutdown


```solidity
function emergencyShutdown() external onlyGovernor;
```

### transfer


```solidity
function transfer(address, uint256) public pure override(IERC20, ERC20) returns (bool);
```

### transferFrom


```solidity
function transferFrom(address, address, uint256) public pure override(IERC20, ERC20) returns (bool);
```

### _mintTip


```solidity
function _mintTip(address account, uint256 amount) internal virtual override;
```

### _reallocateAllAssets


```solidity
function _reallocateAllAssets(RebalanceData[] calldata rebalanceData) internal returns (uint256 totalMoved);
```

### _board


```solidity
function _board(address ark, uint256 amount) internal;
```

### _disembark


```solidity
function _disembark(address ark, uint256 amount) internal;
```

### _move


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


