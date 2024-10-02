// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IComet} from "../../interfaces/compound-v3/IComet.sol";
import {ICometRewards} from "../../interfaces/compound-v3/ICometRewards.sol";
import "../Ark.sol";

/**
 * @title CompoundV3Ark
 * @notice Implementation of Ark for Compound V3 protocol
 * @dev This contract manages deposits, withdrawals, and reward harvesting for Compound V3
 */
contract CompoundV3Ark is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Compound V3 Comet contract
    IComet public comet;
    /// @notice The Compound V3 CometRewards contract
    ICometRewards public cometRewards;

    /**
     * @notice Struct to hold reward token information
     * @param rewardToken The address of the reward token
     */
    struct RewardsData {
        address rewardToken;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for CompoundV3Ark
     * @param _comet Address of the Compound V3 Comet contract
     * @param _cometRewards Address of the Compound V3 CometRewards contract
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _comet,
        address _cometRewards,
        ArkParams memory _params
    ) Ark(_params) {
        comet = IComet(_comet);
        cometRewards = ICometRewards(_cometRewards);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets()
        public
        view
        override
        returns (uint256 suppliedAssets)
    {
        suppliedAssets = comet.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets into Compound V3
     * @param amount Amount of assets to deposit
     * @param /// boardData Additional data for boarding (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.token.approve(address(comet), amount);
        comet.supply(address(config.token), amount);
    }

    /**
     * @notice Withdraws assets from Compound V3
     * @param amount Amount of assets to withdraw
     * @param /// disembarkData Additional data for disembarking (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        comet.withdraw(address(config.token), amount);
    }

    /**
     * @notice Harvests rewards from Compound V3
     * @param data Encoded RewardsData struct containing reward token information
     * @return rewardTokens Array of reward token addresses
     * @return rewardAmounts Array of reward token amounts
     */
    function _harvest(
        bytes calldata data
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);

        RewardsData memory rewardsData = abi.decode(data, (RewardsData));
        rewardTokens[0] = rewardsData.rewardToken;
        cometRewards.claim(address(comet), address(this), true);

        rewardAmounts[0] = IERC20(rewardsData.rewardToken).balanceOf(
            address(this)
        );
        IERC20(rewardsData.rewardToken).safeTransfer(raft(), rewardAmounts[0]);

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice Validates the boarding data (unused in this implementation)
     * @param data The boarding data to validate
     */
    function _validateBoardData(bytes calldata data) internal override {}

    /**
     * @notice Validates the disembarking data (unused in this implementation)
     * @param data The disembarking data to validate
     */
    function _validateDisembarkData(bytes calldata data) internal override {}
}
