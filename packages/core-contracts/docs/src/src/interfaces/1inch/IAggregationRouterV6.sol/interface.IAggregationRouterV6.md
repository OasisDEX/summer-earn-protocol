# IAggregationRouterV6
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/1inch/IAggregationRouterV6.sol)


## Functions
### swap


```solidity
function swap(
    address executor,
    SwapDescription calldata desc,
    bytes calldata permit,
    bytes calldata data
)
    external
    payable
    returns (uint256 returnAmount, uint256 spentAmount);
```

## Structs
### SwapDescription

```solidity
struct SwapDescription {
    IERC20 srcToken;
    IERC20 dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
}
```

