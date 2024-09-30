# IUniversalRewardsDistributor
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/morpho/IUniversalRewardsDistributor.sol)

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

