# AuctionDefaultParameters
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/CommonAuctionTypes.sol)

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

