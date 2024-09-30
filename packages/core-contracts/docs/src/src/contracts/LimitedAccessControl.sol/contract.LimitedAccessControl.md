# LimitedAccessControl
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/LimitedAccessControl.sol)

**Inherits:**
AccessControl, [IAccessControlErrors](/src/errors/IAccessControlErrors.sol/interface.IAccessControlErrors.md)

*This contract extends OpenZeppelin's AccessControl, disabling direct role granting and revoking.
It's designed to be used as a base contract for more specific access control implementations.*


## Functions
### grantRole

This function always reverts with a DirectGrantIsDisabled error.

*Overrides the grantRole function from AccessControl to disable direct role granting.*


```solidity
function grantRole(bytes32, address) public view override;
```

### revokeRole

This function always reverts with a DirectRevokeIsDisabled error.

*Overrides the revokeRole function from AccessControl to disable direct role revoking.*


```solidity
function revokeRole(bytes32, address) public view override;
```

