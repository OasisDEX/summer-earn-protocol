# IPoolDataProvider
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/aave-v3/IPoolDataProvider.sol)

**Author:**
Aave

Defines the basic interface of a PoolDataProvider


## Functions
### ADDRESSES_PROVIDER

Returns the address for the PoolAddressesProvider contract.


```solidity
function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IPoolAddressesProvider`|The address for the PoolAddressesProvider contract|


### getAllReservesTokens

Returns the list of the existing reserves in the pool.

*Handling MKR and ETH in a different way since they do not have standard `symbol` functions.*


```solidity
function getAllReservesTokens() external view returns (TokenData[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`TokenData[]`|The list of reserves, pairs of symbols and addresses|


### getAllATokens

Returns the list of the existing ATokens in the pool.


```solidity
function getAllATokens() external view returns (TokenData[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`TokenData[]`|The list of ATokens, pairs of symbols and addresses|


### getReserveConfigurationData

Returns the configuration data of the reserve

*Not returning borrow and supply caps for compatibility, nor pause flag*


```solidity
function getReserveConfigurationData(address asset)
    external
    view
    returns (
        uint256 decimals,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        uint256 reserveFactor,
        bool usageAsCollateralEnabled,
        bool borrowingEnabled,
        bool stableBorrowRateEnabled,
        bool isActive,
        bool isFrozen
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`decimals`|`uint256`|The number of decimals of the reserve|
|`ltv`|`uint256`|The ltv of the reserve|
|`liquidationThreshold`|`uint256`|The liquidationThreshold of the reserve|
|`liquidationBonus`|`uint256`|The liquidationBonus of the reserve|
|`reserveFactor`|`uint256`|The reserveFactor of the reserve|
|`usageAsCollateralEnabled`|`bool`|True if the usage as collateral is enabled, false otherwise|
|`borrowingEnabled`|`bool`|True if borrowing is enabled, false otherwise|
|`stableBorrowRateEnabled`|`bool`|True if stable rate borrowing is enabled, false otherwise|
|`isActive`|`bool`|True if it is active, false otherwise|
|`isFrozen`|`bool`|True if it is frozen, false otherwise|


### getReserveEModeCategory

Returns the efficiency mode category of the reserve


```solidity
function getReserveEModeCategory(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The eMode id of the reserve|


### getReserveCaps

Returns the caps parameters of the reserve


```solidity
function getReserveCaps(address asset) external view returns (uint256 borrowCap, uint256 supplyCap);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`borrowCap`|`uint256`|The borrow cap of the reserve|
|`supplyCap`|`uint256`|The supply cap of the reserve|


### getPaused

Returns if the pool is paused


```solidity
function getPaused(address asset) external view returns (bool isPaused);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isPaused`|`bool`|True if the pool is paused, false otherwise|


### getSiloedBorrowing

Returns the siloed borrowing flag


```solidity
function getSiloedBorrowing(address asset) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the asset is siloed for borrowing|


### getLiquidationProtocolFee

Returns the protocol fee on the liquidation bonus


```solidity
function getLiquidationProtocolFee(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The protocol fee on liquidation|


### getUnbackedMintCap

Returns the unbacked mint cap of the reserve


```solidity
function getUnbackedMintCap(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The unbacked mint cap of the reserve|


### getDebtCeiling

Returns the debt ceiling of the reserve


```solidity
function getDebtCeiling(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The debt ceiling of the reserve|


### getDebtCeilingDecimals

Returns the debt ceiling decimals


```solidity
function getDebtCeilingDecimals() external pure returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The debt ceiling decimals|


### getReserveData

Returns the reserve data


```solidity
function getReserveData(address asset)
    external
    view
    returns (
        uint256 unbacked,
        uint256 accruedToTreasuryScaled,
        uint256 totalAToken,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 liquidityRate,
        uint256 variableBorrowRate,
        uint256 stableBorrowRate,
        uint256 averageStableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex,
        uint40 lastUpdateTimestamp
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`unbacked`|`uint256`|The amount of unbacked tokens|
|`accruedToTreasuryScaled`|`uint256`|The scaled amount of tokens accrued to treasury that is to be minted|
|`totalAToken`|`uint256`|The total supply of the aToken|
|`totalStableDebt`|`uint256`|The total stable debt of the reserve|
|`totalVariableDebt`|`uint256`|The total variable debt of the reserve|
|`liquidityRate`|`uint256`|The liquidity rate of the reserve|
|`variableBorrowRate`|`uint256`|The variable borrow rate of the reserve|
|`stableBorrowRate`|`uint256`|The stable borrow rate of the reserve|
|`averageStableBorrowRate`|`uint256`|The average stable borrow rate of the reserve|
|`liquidityIndex`|`uint256`|The liquidity index of the reserve|
|`variableBorrowIndex`|`uint256`|The variable borrow index of the reserve|
|`lastUpdateTimestamp`|`uint40`|The timestamp of the last update of the reserve|


### getATokenTotalSupply

Returns the total supply of aTokens for a given asset


```solidity
function getATokenTotalSupply(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply of the aToken|


### getTotalDebt

Returns the total debt for a given asset


```solidity
function getTotalDebt(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total debt for asset|


### getUserReserveData

Returns the user data in a reserve


```solidity
function getUserReserveData(
    address asset,
    address user
)
    external
    view
    returns (
        uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        uint256 principalStableDebt,
        uint256 scaledVariableDebt,
        uint256 stableBorrowRate,
        uint256 liquidityRate,
        uint40 stableRateLastUpdated,
        bool usageAsCollateralEnabled
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|
|`user`|`address`|The address of the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentATokenBalance`|`uint256`|The current AToken balance of the user|
|`currentStableDebt`|`uint256`|The current stable debt of the user|
|`currentVariableDebt`|`uint256`|The current variable debt of the user|
|`principalStableDebt`|`uint256`|The principal stable debt of the user|
|`scaledVariableDebt`|`uint256`|The scaled variable debt of the user|
|`stableBorrowRate`|`uint256`|The stable borrow rate of the user|
|`liquidityRate`|`uint256`|The liquidity rate of the reserve|
|`stableRateLastUpdated`|`uint40`|The timestamp of the last update of the user stable rate|
|`usageAsCollateralEnabled`|`bool`|True if the user is using the asset as collateral, false otherwise|


### getReserveTokensAddresses

Returns the token addresses of the reserve


```solidity
function getReserveTokensAddresses(address asset)
    external
    view
    returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`aTokenAddress`|`address`|The AToken address of the reserve|
|`stableDebtTokenAddress`|`address`|The StableDebtToken address of the reserve|
|`variableDebtTokenAddress`|`address`|The VariableDebtToken address of the reserve|


### getInterestRateStrategyAddress

Returns the address of the Interest Rate strategy


```solidity
function getInterestRateStrategyAddress(address asset) external view returns (address irStrategyAddress);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`irStrategyAddress`|`address`|The address of the Interest Rate strategy|


### getFlashLoanEnabled

Returns whether the reserve has FlashLoans enabled or disabled


```solidity
function getFlashLoanEnabled(address asset) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the underlying asset of the reserve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if FlashLoans are enabled, false otherwise|


## Structs
### TokenData

```solidity
struct TokenData {
    string symbol;
    address tokenAddress;
}
```

