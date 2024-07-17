// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import {IRaftEvents} from "../src/interfaces/IRaftEvents.sol";
import {Raft} from "../src/contracts/Raft.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SwapData} from "../src/types/RaftTypes.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";

contract RaftTest is Test, IRaftEvents {
    Raft public raft;

    address public governor = address(1);
    address public mockArk = address(5);
    address public mockSwapProvider = address(6);
    address public mockToken = address(7);
    address public keeper = address(8);

    function setUp() public {
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        raft = new Raft(mockSwapProvider, address(accessManager));

        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);
    }

    function test_Harvest() public {
        address mockRewardToken = address(6);

        // Arrange
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk(mockArk).harvest.selector,
                mockRewardToken
            ),
            abi.encode(100)
        );

        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(mockArk, mockRewardToken);

        // Act
        raft.harvest(mockArk, mockRewardToken);
    }

    function test_HarvestAndReinvest() public {
        // Arrange
        address mockRewardToken = address(6);
        uint256 rewardAmount = 100;
        uint256 balanceAfterSwap = 200;

        // Harvest so the mapping is populated
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk(mockArk).harvest.selector,
                mockRewardToken
            ),
            abi.encode(100)
        );

        // Mock swap call
        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: rewardAmount,
            receiveAtLeast: rewardAmount,
            withData: abi.encode()
        });

        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(
                IERC20(mockRewardToken).approve.selector,
                mockSwapProvider,
                rewardAmount
            ),
            abi.encode(true)
        );

        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk(mockArk).token.selector
            ),
            abi.encode(mockToken)
        );

        // Mock token balance after swap
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(
                IERC20(mockToken).balanceOf.selector,
                address(raft)
            ),
            abi.encode(balanceAfterSwap)
        );

        /* Reinvest */
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(
                IERC20(mockToken).balanceOf.selector,
                address(raft)
            ),
            abi.encode(balanceAfterSwap)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(
                IERC20(mockToken).approve.selector,
                mockArk,
                balanceAfterSwap
            ),
            abi.encode(true)
        );

        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk(mockArk).boardFromRaft.selector,
                balanceAfterSwap
            ),
            abi.encode()
        );

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit RewardSwapped(
            mockRewardToken,
            mockToken,
            rewardAmount,
            balanceAfterSwap
        );

        vm.expectEmit();
        emit RewardReboarded(mockArk, mockRewardToken, rewardAmount, balanceAfterSwap);

        // Act
        vm.prank(keeper);
        raft.harvestAndReboard(mockArk, mockRewardToken, swapData);
    }
}
