# AuctionDefaultParameters
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/CommonAuctionTypes.sol)

Struct containing default parameters for Dutch auctions

*This struct is used to configure the default settings for Dutch auctions in the protocol*


```solidity
struct AuctionDefaultParameters {
    uint40 duration;
    uint256 startPrice;
    uint256 endPrice;
    Percentage kickerRewardPercentage;
    DecayFunctions.DecayType decayType;
}
```

