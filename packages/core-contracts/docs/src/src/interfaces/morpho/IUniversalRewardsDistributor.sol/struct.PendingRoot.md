# PendingRoot
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/morpho/IUniversalRewardsDistributor.sol)

The pending root struct for a merkle tree distribution during the timelock.


```solidity
struct PendingRoot {
    bytes32 root;
    bytes32 ipfsHash;
    uint256 validAt;
}
```

