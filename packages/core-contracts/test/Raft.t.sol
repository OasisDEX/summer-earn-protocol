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
import "../src/errors/RaftErrors.sol";

contract RaftTest is Test, IRaftEvents {
    Raft public raft;
    IProtocolAccessManager public accessManager;

    address public governor = address(1);
    address public mockArk = address(5);
    address public mockToken = address(7);
    address public superKeeper = address(8);
    address public mockRewardToken = address(9);
    address public newSwapProvider = address(10);

    MockSwapProvider public mockSwapProvider;

    uint256 constant REWARD_AMOUNT = 100;
    uint256 constant BALANCE_AFTER_SWAP = 200;

    function setUp() public {
        mockSwapProvider = new MockSwapProvider();

        // Setup the access manager and grant roles
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(superKeeper);

        // Deploy the Raft contract
        raft = new Raft(address(mockSwapProvider), address(accessManager));

        // Setup mock calls
        _setupMockCalls();
    }

    function test_Harvest() public {
        // Expect the ArkHarvested event to be emitted
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(mockArk, mockRewardToken);

        // Perform the harvest
        raft.harvest(mockArk, mockRewardToken, bytes(""));

        // Assert that the harvested rewards were recorded
        assertEq(
            raft.getHarvestedRewards(mockArk, mockRewardToken),
            REWARD_AMOUNT
        );
    }

    function test_HarvestAndBoard() public {
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
        emit RewardBoarded(
            mockArk,
            mockRewardToken,
            REWARD_AMOUNT,
            BALANCE_AFTER_SWAP
        );

        // Perform harvestAndBoard
        vm.prank(superKeeper);
        raft.harvestAndBoard(mockArk, mockRewardToken, swapData, bytes(""));

        // Assert that harvested rewards were reset
        assertEq(raft.getHarvestedRewards(mockArk, mockRewardToken), 0);
    }

    function test_SwapAndBoard() public {
        // Setup initial harvested rewards
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.harvest.selector, mockRewardToken),
            abi.encode(REWARD_AMOUNT)
        );
        raft.harvest(mockArk, mockRewardToken, bytes(""));

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
        emit RewardBoarded(
            mockArk,
            mockRewardToken,
            REWARD_AMOUNT,
            BALANCE_AFTER_SWAP
        );

        // Perform swapAndBoard
        vm.prank(superKeeper);
        raft.swapAndBoard(mockArk, mockRewardToken, swapData);

        // Assert that harvested rewards were reset
        assertEq(raft.getHarvestedRewards(mockArk, mockRewardToken), 0);
    }

    function test_SetSwapProvider() public {
        // Expect revert when called by non-superKeeper
        vm.expectRevert();
        raft.setSwapProvider(newSwapProvider);

        // Set new swap provider
        vm.prank(superKeeper);
        raft.setSwapProvider(newSwapProvider);

        // Assert that the swap provider was updated
        assertEq(raft.swapProvider(), newSwapProvider);
    }

    function test_SwapFailure() public {
        raft.harvest(mockArk, mockRewardToken, bytes(""));

        // Setup swap data
        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT,
            receiveAtLeast: REWARD_AMOUNT,
            withData: abi.encodeWithSignature("someFunction(uint256)", 123)
        });

        // Mock failed swap
        mockSwapProvider.setShouldFail(true);

        // Expect revert on swap failure
        vm.expectRevert(abi.encodeWithSelector(RewardsSwapFailed.selector, superKeeper));

        // Attempt to perform swapAndBoard
        vm.prank(superKeeper);
        raft.swapAndBoard(mockArk, mockRewardToken, swapData);
    }

    function test_InsufficientSwapOutput() public {
        raft.harvest(mockArk, mockRewardToken, bytes(""));

        // Setup swap data with higher receiveAtLeast
        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT,
            receiveAtLeast: BALANCE_AFTER_SWAP + 1, // Set higher than actual output
            withData: abi.encode()
        });

        // Expect revert due to insufficient swap output
        vm.expectRevert(abi.encodeWithSelector(ReceivedLess.selector, BALANCE_AFTER_SWAP + 1, BALANCE_AFTER_SWAP));

        // Attempt to perform swapAndBoard
        vm.prank(superKeeper);
        raft.swapAndBoard(mockArk, mockRewardToken, swapData);
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

        // Mock Ark token and board calls
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.token.selector),
            abi.encode(mockToken)
        );
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.board.selector, BALANCE_AFTER_SWAP),
            abi.encode()
        );
    }
}

contract MockSwapProvider {
    bool public shouldFail = false;

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    fallback() external {
        require(!shouldFail, "Swap failed");
    }
}