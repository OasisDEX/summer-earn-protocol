// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IComet} from "../../interfaces/compound-v3/IComet.sol";
import {ICometRewards} from "../../interfaces/compound-v3/ICometRewards.sol";
import "../Ark.sol";

/**
 * @title CompoundV3Ark
 * @notice Ark contract for managing token supply and yield generation for Compound V3.
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and claiming rewards on Compound V3.
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
    function totalAssets() public view override returns (uint256 assets) {
        assets = comet.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev CompoundV3Ark is always withdrawable
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        if (!comet.isWithdrawPaused()) {
            withdrawableAssets = totalAssets();
        }
    }

    /**
     * @notice Deposits assets into Compound V3
     * @param amount Amount of assets to deposit
     * @param /// boardData Additional data for boarding (unused in this implementation)
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(comet), amount);
        comet.supply(address(config.asset), amount);
    }

    /**
     * @notice Withdraws assets from Compound V3
     * @param amount Amount of assets to withdraw
     * @param /// disembarkData Additional data for disembarking (unused in this implementation)
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        comet.withdraw(address(config.asset), amount);
    }

    /**
     * @notice Harvests rewards from Compound V3
     * @return rewardTokens Array of reward token addresses
     * @return rewardAmounts Array of reward token amounts
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);

        ICometRewards.RewardConfig memory config = ICometRewards(
            address(cometRewards)
        ).rewardConfig(address(comet));

        rewardTokens[0] = config.token;

        address raft = raft();
        uint256 balanceBefore = IERC20(rewardTokens[0]).balanceOf(raft);
        cometRewards.claimTo(address(comet), address(this), raft, true);
        uint256 balanceAfter = IERC20(rewardTokens[0]).balanceOf(raft);

        rewardAmounts[0] = balanceAfter - balanceBefore;

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
