// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ISummerStaking {
    enum Bucket {
        NoLockup,
        ShortTerm,
        ThreeToSixMonths,
        SixToTwelveMonths,
        OneToTwoYears,
        TwoToFourYears
    }

    // Core actions
    function stakeWithNewLockup(uint256 amount, uint256 lockupPeriod) external;
    function addToStake(uint256 stakeIndex, uint256 amount) external;
    function unstakeFromLockup(uint256 stakeIndex, uint256 amount) external;

    // Views/helpers
    function calculateWeightedStake(
        uint256 amount,
        uint256 lockupPeriod
    ) external view returns (uint256);
    function calculatePenalty(
        address user,
        uint256 stakeIndex
    ) external view returns (uint256);
    function weightedBalanceOf(address account) external view returns (uint256);

    // User stakes
    function getUserStakesCount(address user) external view returns (uint256);
    function getUserStake(
        address user,
        uint256 index
    )
        external
        view
        returns (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 lockupPeriod
        );

    // Buckets
    function updateLockupBucketCap(Bucket bucket, uint256 newCap) external;
    function getBucketTotalStaked(
        Bucket bucket
    ) external view returns (uint256);
    function getBucketDetails(
        Bucket bucket
    )
        external
        view
        returns (
            uint256 cap,
            uint256 staked,
            uint256 minLockupPeriod,
            uint256 maxLockupPeriod
        );

    function getAllBucketInfo()
        external
        view
        returns (
            Bucket[] memory buckets,
            uint256[] memory caps,
            uint256[] memory stakedAmounts,
            uint256[] memory minPeriods,
            uint256[] memory maxPeriods
        );
}
