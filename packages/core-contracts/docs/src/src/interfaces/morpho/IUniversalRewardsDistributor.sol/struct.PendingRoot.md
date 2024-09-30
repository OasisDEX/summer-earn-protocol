# PendingRoot
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/interfaces/morpho/IUniversalRewardsDistributor.sol)

The pending root struct for a merkle tree distribution during the timelock.


```solidity
struct PendingRoot {
    bytes32 root;
    bytes32 ipfsHash;
    uint256 validAt;
}
```

