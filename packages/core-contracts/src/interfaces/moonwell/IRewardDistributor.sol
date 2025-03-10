struct MarketConfig {
    // The owner/admin of the emission config
    address owner;
    // The emission token
    address emissionToken;
    // Scheduled to end at this time
    uint endTime;
    // Supplier global state
    uint224 supplyGlobalIndex;
    uint32 supplyGlobalTimestamp;
    // Borrower global state
    uint224 borrowGlobalIndex;
    uint32 borrowGlobalTimestamp;
    uint supplyEmissionsPerSec;
    uint borrowEmissionsPerSec;
}

interface IRewardDistributor {
    function claimReward(address payable holder) external;
    function getAllMarketConfigs(
        address _mToken
    ) external view returns (MarketConfig[] memory);
}
