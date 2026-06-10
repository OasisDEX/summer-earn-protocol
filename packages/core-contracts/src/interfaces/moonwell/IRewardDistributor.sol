pragma solidity 0.8.28;

/// @notice Emission configuration and global accounting state for a market's reward token
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

/// @title IRewardDistributor
/// @notice Minimal interface for the Moonwell reward distributor
interface IRewardDistributor {
    /// @notice Claims all accrued rewards for a holder across markets
    /// @param holder The address to claim rewards for
    function claimReward(address payable holder) external;
    /// @notice Returns all reward emission configurations for a market
    /// @param _mToken The market (mToken) to query
    /// @return The market's reward configurations
    function getAllMarketConfigs(
        address _mToken
    ) external view returns (MarketConfig[] memory);
}
