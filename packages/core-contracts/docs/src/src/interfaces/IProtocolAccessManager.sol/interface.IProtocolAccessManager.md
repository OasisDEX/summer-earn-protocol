# IProtocolAccessManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/IProtocolAccessManager.sol)

Defines system roles and provides role based remote-access control for
contracts that inherit from ProtocolAccessManaged contract


## Functions
### grantAdminRole

Grants the Admin role to a given account


```solidity
function grantAdminRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to which the Admin role will be granted|


### revokeAdminRole

Revokes the Admin role from a given account


```solidity
function revokeAdminRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account from which the Admin role will be revoked|


### grantGovernorRole

Grants the Governor role to a given account


```solidity
function grantGovernorRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to which the Governor role will be granted|


### revokeGovernorRole

Revokes the Governor role from a given account


```solidity
function revokeGovernorRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account from which the Governor role will be revoked|


### grantKeeperRole

Grants the Keeper role to a given account


```solidity
function grantKeeperRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to which the Keeper role will be granted|


### revokeKeeperRole

Revokes the Keeper role from a given account


```solidity
function revokeKeeperRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account from which the Keeper role will be revoked|


### grantSuperKeeperRole

Grants the Super Keeper role to a given account


```solidity
function grantSuperKeeperRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to which the Super Keeper role will be granted|


### revokeSuperKeeperRole

Revokes the Super Keeper role from a given account


```solidity
function revokeSuperKeeperRole(address account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account from which the Super Keeper role will be revoked|


