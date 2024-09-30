# ProtocolAccessManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/ProtocolAccessManager.sol)

**Inherits:**
[IProtocolAccessManager](/src/interfaces/IProtocolAccessManager.sol/interface.IProtocolAccessManager.md), [LimitedAccessControl](/src/contracts/LimitedAccessControl.sol/contract.LimitedAccessControl.md)


## State Variables
### GOVERNOR_ROLE
*The Governor role is in charge of setting the parameters of the system
and also has the power to manage the different Fleet Commander roles.*


```solidity
bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
```


### KEEPER_ROLE
*The Keeper role is in charge of rebalancing the funds between the different
Arks through the Fleet Commander*


```solidity
bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
```


### SUPER_KEEPER_ROLE
*The Super Keeper role is in charge of rebalancing the funds between the different
Arks through the Fleet Commander*


```solidity
bytes32 public constant SUPER_KEEPER_ROLE = keccak256("SUPER_KEEPER_ROLE");
```


### COMMANDER_ROLE
*The Commander role is assigned to a FleetCommander and is used to restrict
with whom associated arks can interact*


```solidity
bytes32 public constant COMMANDER_ROLE = keccak256("COMMANDER_ROLE");
```


## Functions
### constructor


```solidity
constructor(address governor);
```

### onlyAdmin

*Modifier to check that the caller has the Admin role*


```solidity
modifier onlyAdmin();
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

### supportsInterface


```solidity
function supportsInterface(bytes4 interfaceId) public view override returns (bool);
```

### grantAdminRole


```solidity
function grantAdminRole(address account) external onlyAdmin;
```

### revokeAdminRole


```solidity
function revokeAdminRole(address account) external onlyAdmin;
```

### grantGovernorRole


```solidity
function grantGovernorRole(address account) external onlyAdmin;
```

### revokeGovernorRole


```solidity
function revokeGovernorRole(address account) external onlyAdmin;
```

### grantKeeperRole


```solidity
function grantKeeperRole(address account) external onlyGovernor;
```

### revokeKeeperRole


```solidity
function revokeKeeperRole(address account) external onlyGovernor;
```

### grantSuperKeeperRole


```solidity
function grantSuperKeeperRole(address account) external onlyGovernor;
```

### revokeSuperKeeperRole


```solidity
function revokeSuperKeeperRole(address account) external onlyGovernor;
```

