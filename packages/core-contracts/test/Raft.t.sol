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
    IProtocolAccessManager public accessManager;

    address public governor = address(1);
    address public mockArk = address(5);
    address public mockSwapProvider = address(6);
    address public mockToken = address(7);
    address public keeper = address(8);
    address public mockRewardToken = address(9);

    uint256 constant REWARD_AMOUNT = 100;
    uint256 constant BALANCE_AFTER_SWAP = 200;

    function setUp() public {
        // Setup the access manager and grant roles
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);

        // Deploy the Raft contract
        raft = new Raft(mockSwapProvider, address(accessManager));

        // Setup mock calls
        _setupMockCalls();
    }

    function test_Harvest() public {
        // Expect the ArkHarvested event to be emitted
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(mockArk, mockRewardToken);

        // Perform the harvest
        raft.harvest(mockArk, mockRewardToken);

        // Assert that the harvested rewards were recorded
        assertEq(
            raft.getHarvestedRewards(mockArk, mockRewardToken),
            REWARD_AMOUNT
        );
    }

    function test_HarvestAndReboard() public {
        // Setup swap data
        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT,
            receiveAtLeast: REWARD_AMOUNT,
            withData: abi.encode()
        });

        // Expect events to be emitted
        vm.expectEmit(true, true, true, true);
        emit RewardSwapped(
            mockRewardToken,
            mockToken,
            REWARD_AMOUNT,
            BALANCE_AFTER_SWAP
        );

        vm.expectEmit(true, true, true, true);
        emit RewardReboarded(
            mockArk,
            mockRewardToken,
            REWARD_AMOUNT,
            BALANCE_AFTER_SWAP
        );

        // Perform harvestAndReboard
        vm.prank(keeper);
        raft.harvestAndReboard(mockArk, mockRewardToken, swapData);

        // Assert that harvested rewards were reset
        assertEq(raft.getHarvestedRewards(mockArk, mockRewardToken), 0);
    }

    function test_SwapAndReboard() public {
        // Setup initial harvested rewards
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.harvest.selector, mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );
        raft.harvest(mockArk, mockRewardToken);

        // Setup swap data
        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT,
            receiveAtLeast: REWARD_AMOUNT,
            withData: abi.encode()
        });

        // Expect events to be emitted
        vm.expectEmit(true, true, true, true);
        emit RewardSwapped(
            mockRewardToken,
            mockToken,
            REWARD_AMOUNT,
            BALANCE_AFTER_SWAP
        );

        vm.expectEmit(true, true, true, true);
        emit RewardReboarded(
            mockArk,
            mockRewardToken,
            REWARD_AMOUNT,
            BALANCE_AFTER_SWAP
        );

        // Perform swapAndReboard
        vm.prank(keeper);
        raft.swapAndReboard(mockArk, mockRewardToken, swapData);

        // Assert that harvested rewards were reset
        assertEq(raft.getHarvestedRewards(mockArk, mockRewardToken), 0);
    }

    function _setupMockCalls() internal {
        // Mock harvest call
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.harvest.selector, mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );

        // Mock token approvals
        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(
                IERC20.approve.selector,
                mockSwapProvider,
                REWARD_AMOUNT
            ),
            abi.encode(true)
        );
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(
                IERC20.approve.selector,
                mockArk,
                BALANCE_AFTER_SWAP
            ),
            abi.encode(true)
        );

        // Mock token balance calls
        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(raft)),
            abi.encode(BALANCE_AFTER_SWAP)
        );

        // Mock Ark token and boardFromRaft calls
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.token.selector),
            abi.encode(mockToken)
        );
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk.boardFromRaft.selector,
                BALANCE_AFTER_SWAP
            ),
            abi.encode()
        );

        // Mock successful swap provider call
        vm.mockCall(mockSwapProvider, abi.encode(), abi.encode(true));
    }
}
