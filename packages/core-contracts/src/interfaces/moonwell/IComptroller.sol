pragma solidity 0.8.28;

interface IComptroller {
    /**
     * @notice Claim all the WELL accrued by holder in the specified markets
     * @param holder The address to claim WELL for
     * @param mTokens The list of markets to claim WELL in
     */
    function claimReward(
        address payable holder,
        address[] memory mTokens
    ) external;

    /**
     * @notice Claim all the WELL accrued by holder in all markets
     * @param holder The address to claim WELL for
     */
    function claimReward(address payable holder) external;

    function rewardDistributor() external view returns (address);
}
