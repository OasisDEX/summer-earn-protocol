# StorageSlots
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/libraries/StorageSlots.sol)


## State Variables
### TOTAL_ASSETS_STORAGE

```solidity
bytes32 public constant TOTAL_ASSETS_STORAGE =
    keccak256(abi.encode(uint256(keccak256("fleetCommander.storage.totalAssets")) - 1)) & ~bytes32(uint256(0xff));
```


### IS_TOTAL_ASSETS_CACHED_STORAGE

```solidity
bytes32 public constant IS_TOTAL_ASSETS_CACHED_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.isTotalAssetsCached")) - 1)
) & ~bytes32(uint256(0xff));
```


### ARKS_TOTAL_ASSETS_ARRAY_STORAGE

```solidity
bytes32 public constant ARKS_TOTAL_ASSETS_ARRAY_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.arksTotalAssetsArray")) - 1)
) & ~bytes32(uint256(0xff));
```


### ARKS_ADDRESS_ARRAY_STORAGE

```solidity
bytes32 public constant ARKS_ADDRESS_ARRAY_STORAGE =
    keccak256(abi.encode(uint256(keccak256("fleetCommander.storage.arksAddressArray")) - 1)) & ~bytes32(uint256(0xff));
```


### ARKS_LENGTH_STORAGE

```solidity
bytes32 public constant ARKS_LENGTH_STORAGE =
    keccak256(abi.encode(uint256(keccak256("fleetCommander.storage.arksLength")) - 1)) & ~bytes32(uint256(0xff));
```


### WITHDRAWABLE_ARKS_TOTAL_ASSETS_STORAGE

```solidity
bytes32 public constant WITHDRAWABLE_ARKS_TOTAL_ASSETS_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.withdrawableArksTotalAssets")) - 1)
) & ~bytes32(uint256(0xff));
```


### WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE

```solidity
bytes32 public constant WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.withdrawableArksTotalAssetsArray")) - 1)
) & ~bytes32(uint256(0xff));
```


### WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE

```solidity
bytes32 public constant WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.withdrawableArksAddressArray")) - 1)
) & ~bytes32(uint256(0xff));
```


### WITHDRAWABLE_ARKS_LENGTH_STORAGE

```solidity
bytes32 public constant WITHDRAWABLE_ARKS_LENGTH_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.withdrawableArksLength")) - 1)
) & ~bytes32(uint256(0xff));
```


### IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE

```solidity
bytes32 public constant IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE = keccak256(
    abi.encode(uint256(keccak256("fleetCommander.storage.isWithdrawableArksTotalAssetsCached")) - 1)
) & ~bytes32(uint256(0xff));
```


