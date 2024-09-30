# PendingRoot
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/morpho/IUniversalRewardsDistributor.sol)

The pending root struct for a merkle tree distribution during the timelock.


```solidity
struct PendingRoot {
    bytes32 root;
    bytes32 ipfsHash;
    uint256 validAt;
}
```

