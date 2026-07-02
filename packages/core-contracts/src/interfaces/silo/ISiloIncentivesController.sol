// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.28;

/// @notice Rewards accrued for a single incentive program
struct AccruedRewards {
    uint256 amount;
    bytes32 programId;
    address rewardToken;
}
/// @title ISiloIncentivesController
/// @notice Interface for claiming Silo lending-pool incentive rewards
interface ISiloIncentivesController {
    /**
     * @notice Claims reward for an user to the desired address, on all the assets of the lending pool,
     * accumulating the pending rewards
     * @param _to Address that will be receiving the rewards
     * @return accruedRewards The rewards accrued per incentive program
     */
    function claimRewards(
        address _to
    ) external returns (AccruedRewards[] memory accruedRewards);
}
