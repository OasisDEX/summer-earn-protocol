# IUniversalRewardsDistributor
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/morpho/IUniversalRewardsDistributor.sol)

*This interface is used for factorizing IUniversalRewardsDistributorStaticTyping and
IUniversalRewardsDistributor.*

*Consider using the IUniversalRewardsDistributor interface instead of this one.*


## Functions
### setRoot


```solidity
function setRoot(bytes32 newRoot, bytes32 newIpfsHash) external;
```

### claim


```solidity
function claim(
    address account,
    address reward,
    uint256 claimable,
    bytes32[] memory proof
)
    external
    returns (uint256 amount);
```

## Events
### Claimed

```solidity
event Claimed(address indexed account, address indexed reward, uint256 amount);
```

