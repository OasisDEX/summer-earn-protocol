// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseAuctionParameters} from "../types/CommonAuctionTypes.sol";

/**
 * @title IRaftEvents
 * @notice Interface defining events emitted by the Raft contract
 */
interface IRaftEvents {
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
     * @param rewardTokens The addresses of the harvested reward tokens
     * @param rewardAmounts The amounts of the harvested reward tokens
     */
    event ArkHarvested(
        address indexed ark,
        address[] indexed rewardTokens,
        uint256[] indexed rewardAmounts
    );

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

    /**
     * @notice Emitted when a sweepable token is set for an Ark
     * @param ark The address of the Ark contract
     * @param token The address of the token
     * @param isSweepable Whether the token is sweepable
     */
    event SweepableTokenSet(
        address indexed ark,
        address indexed token,
        bool isSweepable
    );

    /**
     * @notice Emitted when auction parameters are set for an Ark's reward token
     * @param ark The address of the Ark contract
     * @param rewardToken The address of the reward token
     * @param parameters The auction parameters
     */
    event ArkAuctionParametersSet(
        address indexed ark,
        address indexed rewardToken,
        BaseAuctionParameters parameters
    );
}
