# IPoolAddressesProvider
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/aave-v3/IPoolAddressesProvider.sol)


## Functions
### getMarketId

Returns the id of the Aave market to which this contract points to.


```solidity
function getMarketId() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The market id|


### setMarketId

Associates an id with a specific PoolAddressesProvider.

*This can be used to create an onchain registry of PoolAddressesProviders to
identify and validate multiple Aave markets.*


```solidity
function setMarketId(string calldata newMarketId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMarketId`|`string`|The market id|


### getAddress

Returns an address by its identifier.

*The returned address might be an EOA or a contract, potentially proxied*

*It returns ZERO if there is no registered address with the given id*


```solidity
function getAddress(bytes32 id) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the registered for the specified id|


### setAddressAsProxy

General function to update the implementation of a proxy registered with
certain `id`. If there is no proxy registered, it will instantiate one and
set as implementation the `newImplementationAddress`.

*IMPORTANT Use this function carefully, only for ids that don't have an explicit
setter function, in order to avoid unexpected consequences*


```solidity
function setAddressAsProxy(bytes32 id, address newImplementationAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The id|
|`newImplementationAddress`|`address`|The address of the new implementation|


### setAddress

Sets an address for an id replacing the address saved in the addresses map.

*IMPORTANT Use this function carefully, as it will do a hard replacement*


```solidity
function setAddress(bytes32 id, address newAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The id|
|`newAddress`|`address`|The address to set|


### getPool

Returns the address of the Pool proxy.


```solidity
function getPool() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The Pool proxy address|


### setPoolImpl

Updates the implementation of the Pool, or creates a proxy
setting the new `pool` implementation when the function is called for the first time.


```solidity
function setPoolImpl(address newPoolImpl) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPoolImpl`|`address`|The new Pool implementation|


### getPoolConfigurator

Returns the address of the PoolConfigurator proxy.


```solidity
function getPoolConfigurator() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The PoolConfigurator proxy address|


### setPoolConfiguratorImpl

Updates the implementation of the PoolConfigurator, or creates a proxy
setting the new `PoolConfigurator` implementation when the function is called for the first time.


```solidity
function setPoolConfiguratorImpl(address newPoolConfiguratorImpl) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPoolConfiguratorImpl`|`address`|The new PoolConfigurator implementation|


### getPriceOracle

Returns the address of the price oracle.


```solidity
function getPriceOracle() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the PriceOracle|


### setPriceOracle

Updates the address of the price oracle.


```solidity
function setPriceOracle(address newPriceOracle) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPriceOracle`|`address`|The address of the new PriceOracle|


### getACLManager

Returns the address of the ACL manager.


```solidity
function getACLManager() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the ACLManager|


### setACLManager

Updates the address of the ACL manager.


```solidity
function setACLManager(address newAclManager) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAclManager`|`address`|The address of the new ACLManager|


### getACLAdmin

Returns the address of the ACL admin.


```solidity
function getACLAdmin() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the ACL admin|


### setACLAdmin

Updates the address of the ACL admin.


```solidity
function setACLAdmin(address newAclAdmin) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAclAdmin`|`address`|The address of the new ACL admin|


### getPriceOracleSentinel

Returns the address of the price oracle sentinel.


```solidity
function getPriceOracleSentinel() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the PriceOracleSentinel|


### setPriceOracleSentinel

Updates the address of the price oracle sentinel.


```solidity
function setPriceOracleSentinel(address newPriceOracleSentinel) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPriceOracleSentinel`|`address`|The address of the new PriceOracleSentinel|


### getPoolDataProvider

Returns the address of the data provider.


```solidity
function getPoolDataProvider() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the DataProvider|


### setPoolDataProvider

Updates the address of the data provider.


```solidity
function setPoolDataProvider(address newDataProvider) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDataProvider`|`address`|The address of the new DataProvider|


## Events
### MarketIdSet
*Emitted when the market identifier is updated.*


```solidity
event MarketIdSet(string indexed oldMarketId, string indexed newMarketId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldMarketId`|`string`|The old id of the market|
|`newMarketId`|`string`|The new id of the market|

### PoolUpdated
*Emitted when the pool is updated.*


```solidity
event PoolUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the Pool|
|`newAddress`|`address`|The new address of the Pool|

### PoolConfiguratorUpdated
*Emitted when the pool configurator is updated.*


```solidity
event PoolConfiguratorUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the PoolConfigurator|
|`newAddress`|`address`|The new address of the PoolConfigurator|

### PriceOracleUpdated
*Emitted when the price oracle is updated.*


```solidity
event PriceOracleUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the PriceOracle|
|`newAddress`|`address`|The new address of the PriceOracle|

### ACLManagerUpdated
*Emitted when the ACL manager is updated.*


```solidity
event ACLManagerUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the ACLManager|
|`newAddress`|`address`|The new address of the ACLManager|

### ACLAdminUpdated
*Emitted when the ACL admin is updated.*


```solidity
event ACLAdminUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the ACLAdmin|
|`newAddress`|`address`|The new address of the ACLAdmin|

### PriceOracleSentinelUpdated
*Emitted when the price oracle sentinel is updated.*


```solidity
event PriceOracleSentinelUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the PriceOracleSentinel|
|`newAddress`|`address`|The new address of the PriceOracleSentinel|

### PoolDataProviderUpdated
*Emitted when the pool data provider is updated.*


```solidity
event PoolDataProviderUpdated(address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldAddress`|`address`|The old address of the PoolDataProvider|
|`newAddress`|`address`|The new address of the PoolDataProvider|

### ProxyCreated
*Emitted when a new proxy is created.*


```solidity
event ProxyCreated(bytes32 indexed id, address indexed proxyAddress, address indexed implementationAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The identifier of the proxy|
|`proxyAddress`|`address`|The address of the created proxy contract|
|`implementationAddress`|`address`|The address of the implementation contract|

### AddressSet
*Emitted when a new non-proxied contract address is registered.*


```solidity
event AddressSet(bytes32 indexed id, address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The identifier of the contract|
|`oldAddress`|`address`|The address of the old contract|
|`newAddress`|`address`|The address of the new contract|

### AddressSetAsProxy
*Emitted when the implementation of the proxy registered with id is updated*


```solidity
event AddressSetAsProxy(
    bytes32 indexed id,
    address indexed proxyAddress,
    address oldImplementationAddress,
    address indexed newImplementationAddress
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The identifier of the contract|
|`proxyAddress`|`address`|The address of the proxy contract|
|`oldImplementationAddress`|`address`|The address of the old implementation contract|
|`newImplementationAddress`|`address`|The address of the new implementation contract|

