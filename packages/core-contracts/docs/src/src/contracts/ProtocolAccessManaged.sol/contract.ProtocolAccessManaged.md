# ProtocolAccessManaged
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/ProtocolAccessManaged.sol)

**Inherits:**
[IAccessControlErrors](/src/errors/IAccessControlErrors.sol/interface.IAccessControlErrors.md)

Defines shared modifiers for all managed contracts


## State Variables
### _accessManager

```solidity
ProtocolAccessManager internal _accessManager;
```


## Functions
### constructor


```solidity
constructor(address accessManager);
```

### onlyGovernor

*Modifier to check that the caller has the Governor role*


```solidity
modifier onlyGovernor();
```

### onlyKeeper

*Modifier to check that the caller has the Keeper role*


```solidity
modifier onlyKeeper();
```

### onlySuperKeeper

*Modifier to check that the caller has the Super Keeper role*


```solidity
modifier onlySuperKeeper();
```

