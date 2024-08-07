// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {SwapData} from "../types/RaftTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArkAccessManaged} from "./ArkAccessManaged.sol";
import "../errors/RaftErrors.sol";

/**
 * @title Raft
 * @notice Manages the harvesting, swapping, and reinvesting of rewards for various Arks.
 * @dev This contract implements the IRaft interface and inherits access control from ArkAccessManaged.
 */
contract Raft is IRaft, ArkAccessManaged {
    address public swapProvider;
    mapping(address ark => mapping(address rewardToken => uint256 harvestedAmount))
        public harvestedRewards;

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
        SwapData calldata swapData,
        bytes calldata extraHarvestData
    ) external onlySuperKeeper {
        _harvest(ark, rewardToken, extraHarvestData);
        _swapAndBoard(ark, rewardToken, swapData);
    }

    /**
     * @inheritdoc IRaft
     * @dev Only callable by addresses with the Keeper role.
     */
    function swapAndBoard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) public onlySuperKeeper {
        _swapAndBoard(ark, rewardToken, swapData);
    }

    /**
     * @inheritdoc IRaft
     */
    function harvest(
        address ark,
        address rewardToken,
        bytes calldata extraHarvestData
    ) public {
        _harvest(ark, rewardToken, extraHarvestData);
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

    function _harvest(
        address ark,
        address rewardToken,
        bytes calldata extraHarvestData
    ) internal {
        uint256 harvestedAmount = IArk(ark).harvest(
            rewardToken,
            extraHarvestData
        );
        harvestedRewards[ark][rewardToken] += harvestedAmount;
        emit ArkHarvested(ark, rewardToken);
    }

    function _swapAndBoard(
        address ark,
        address rewardToken,
        SwapData calldata swapData
    ) internal {
        uint256 harvestedAmount = harvestedRewards[ark][swapData.fromAsset];

        // Ensure we're not trying to swap more than what's harvested
        if (swapData.amount > harvestedAmount) {
            revert SwapAmountExceedsHarvestedAmount(
                swapData.amount,
                harvestedAmount,
                rewardToken
            );
        }

        uint256 preSwapRewardBalance = IERC20(rewardToken).balanceOf(
            address(this)
        );
        _swap(ark, swapData);
        uint256 postSwapRewardBalance = IERC20(rewardToken).balanceOf(
            address(this)
        );

        uint256 swappedAmount = postSwapRewardBalance - preSwapRewardBalance;

        _board(ark, rewardToken);

        uint256 remainingRewards = harvestedAmount - swappedAmount;
        harvestedRewards[ark][rewardToken] = remainingRewards;
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
        IERC20 fleetToken = IArk(ark).token();
        uint256 balance = fleetToken.balanceOf(address(this));
        IERC20(fleetToken).approve(ark, balance);
        IArk(ark).board(balance);

        emit RewardBoarded(ark, rewardToken, address(fleetToken), balance);
    }
}
