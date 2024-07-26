// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {SwapData} from "../types/RaftTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../errors/RaftErrors.sol";
import "./ArkAccessManaged.sol";

/**
 * @title Raft
 * @notice Manages the harvesting, swapping, and reinvesting of rewards for various Arks.
 * @dev This contract implements the IRaft interface and inherits access control from ArkAccessManaged.
 */
contract Raft is IRaft, ArkAccessManaged {
    address public swapProvider;
    mapping(address => mapping(address => uint256)) public harvestedRewards;

    /**
     * @notice Constructs a new Raft contract.
     * @param _swapProvider_ The address of the swap provider (e.g., 1inch) used for token exchanges.
     * @param accessManager The address of the AccessManager contract for role-based permissions.
     */
    constructor(
        address _swapProvider_,
        address accessManager
    ) ArkAccessManaged(accessManager) {
        swapProvider = _swapProvider_;
    }

    /**
     * @inheritdoc IRaft
     * @dev Only callable by addresses with the Keeper role.
     */
    function harvestAndBoard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external onlySuperKeeper {
        harvest(ark, rewardToken);
        _swap(ark, swapData);
        _board(ark, rewardToken);
    }

    /**
     * @inheritdoc IRaft
     * @dev Only callable by addresses with the Keeper role.
     */
    function swapAndBoard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) external onlySuperKeeper {
        _swap(ark, swapData);
        _board(ark, rewardToken);
    }

    /**
     * @inheritdoc IRaft
     */
    function harvest(address ark, address rewardToken) public {
        uint256 harvestedAmount = IArk(ark).harvest(rewardToken);
        harvestedRewards[ark][rewardToken] += harvestedAmount;
        emit ArkHarvested(ark, rewardToken);
    }

    function setSwapProvider(address newProvider) public onlySuperKeeper {
        swapProvider = newProvider;
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

    /**
     * @dev Internal function to perform a swap operation using the swap provider.
     * @param ark The address of the Ark contract associated with the swap.
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
     * @dev Internal function to reinvest harvested rewards back into the Ark.
     * @param ark The address of the Ark contract to reinvest into.
     * @param rewardToken The address of the reward token being reinvested.
     */
    function _board(address ark, address rewardToken) internal {
        uint256 preSwapRewardBalance = harvestedRewards[ark][rewardToken];

        if (preSwapRewardBalance == 0) {
            revert NoRewardsToReinvest(ark, rewardToken);
        }

        uint256 balance = IArk(ark).token().balanceOf(address(this));
        IERC20(IArk(ark).token()).approve(ark, balance);
        IArk(ark).board(balance);

        harvestedRewards[ark][rewardToken] = 0;

        emit RewardBoarded(ark, rewardToken, preSwapRewardBalance, balance);
    }
}
