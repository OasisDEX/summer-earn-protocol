# AuctionDefaultParameters
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/CommonAuctionTypes.sol)

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

