// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../types/RaftTypes.sol";

/**
 * @title IRaftEvents
 * @notice Interface defining events emitted by the Raft contract
 */
interface IRaftEvents {
    /**
     * @notice Emitted when the auction configuration is updated
     * @param newConfig The new auction configuration
     */
    event AuctionDefaultParametersUpdated(AuctionDefaultParameters newConfig);

    /**
     * @notice Emitted when a new auction is started for an Ark's reward token
     * @param auctionId The unique identifier of the auction
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token being auctioned
     * @param amount The amount of tokens being auctioned
     */
    event ArkRewardTokenAuctionStarted(
        uint256 auctionId,
        address ark,
        address rewardToken,
        uint256 amount
    );

    /**
     * @notice Emitted when rewards are harvested from an Ark
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the harvested reward token
     */
    event ArkHarvested(address indexed ark, address indexed rewardToken);

    /**
     * @notice Emitted when auctioned rewards are boarded back into an Ark
     * @param ark The address of the Ark contract
     * @param fromRewardToken The address of the original reward token
     * @param toFleetToken The address of the token boarded into the Ark
     * @param amountReboarded The amount of tokens reboarded
     */
    event RewardBoarded(
        address indexed ark,
        address indexed fromRewardToken,
        address indexed toFleetToken,
        uint256 amountReboarded
    );
}
