// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {SwapData} from "../types/RaftTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../errors/RaftErrors.sol";

/**
 * @custom:see IRaft
 */
contract Raft is IRaft {
    address public swapProvider;

    mapping(address => mapping(address => uint256)) public harvestedRewards;

    constructor(address _swapProvider) {
        swapProvider = _swapProvider;
    }

    /**
     * @inheritdoc IRaft
     */
    function harvestAndReinvest(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external {
        harvest(ark, rewardToken);
        _swap(ark, swapData);
    }

    /**
     * @inheritdoc IRaft
     */
    function swapAndReinvest(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external {
        _swap(ark, swapData);
        _reinvest(ark, rewardToken);
    }

    /**
     * @inheritdoc IRaft
     */
    function harvest(address ark, address rewardToken) public {
        uint256 harvestedAmount = IArk(ark).harvest(rewardToken);

        harvestedRewards[ark][rewardToken] += harvestedAmount;

        emit ArkHarvested(ark, rewardToken);
    }

    /**
     * @dev Internal function to perform a swap operation.
     * @param ark The address of the Ark contract.
     * @param swapData Data required for the swap operation.
     */
    function _swap(address ark, SwapData calldata swapData) internal {
        IERC20(swapData.fromAsset).approve(swapProvider, swapData.amount);

        (bool success, ) = swapProvider.call(swapData.withData);

        if (!success) {
            revert RewardsSwapFailed(msg.sender);
        }

        uint256 balance = IArk(ark).token().balanceOf(address(this));

        if (balance < swapData.receiveAtLeast) {
            revert ReceivedLess(swapData.receiveAtLeast, balance);
        }

        emit RewardSwapped(
            swapData.fromAsset,
            address(IArk(ark).token()),
            swapData.amount,
            balance
        );
    }

    /**
     * @dev Internal function to reinvest harvested rewards.
     * @param ark The address of the Ark contract.
     * @param rewardToken The address of the reward token to be reinvested.
     */
    function _reinvest(address ark, address rewardToken) internal {
        uint256 rewardBalance = harvestedRewards[ark][rewardToken];
        if (rewardBalance == 0) {
            revert NoRewardsToReinvest(ark, rewardToken);
        }

        IERC20(rewardToken).approve(ark, rewardBalance);
        IArk(ark).board(rewardBalance);

        harvestedRewards[ark][rewardToken] = 0;

        emit RewardReinvested(ark, rewardToken, rewardBalance);
    }

    /**
     * @inheritdoc IRaft
     */
    function getHarvestedRewards(
        address ark,
        address rewardToken
    ) external view returns (uint256) {
        return harvestedRewards[ark][rewardToken];
    }
}
