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
import "../src/errors/AccessControlErrors.sol";

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
    uint256 constant BALANCE_BEFORE_SWAP = 0;
    uint256 constant BALANCE_AFTER_SWAP = 200;

    function setUp() public {
        mockSwapProvider = new MockSwapProvider();

        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantSuperKeeperRole(superKeeper);

        raft = new Raft(address(mockSwapProvider), address(accessManager));

        _setupMockCalls();
    }

    function test_Harvest() public {
        vm.expectEmit(true, true, true, true);
        emit ArkHarvested(mockArk, mockRewardToken);

        raft.harvest(mockArk, mockRewardToken, bytes(""));

        assertEq(
            raft.getHarvestedRewards(mockArk, mockRewardToken),
            REWARD_AMOUNT
        );
    }

    function test_HarvestAndBoard() public {
        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT,
            receiveAtLeast: REWARD_AMOUNT,
            withData: abi.encode()
        });

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
            address(mockToken),
            BALANCE_AFTER_SWAP
        );

        vm.prank(superKeeper);
        raft.harvestAndBoard(mockArk, mockRewardToken, swapData, bytes(""));
    }

    function test_SwapAndBoard() public {
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk.harvest.selector,
                mockRewardToken,
                bytes("")
            ),
            abi.encode(REWARD_AMOUNT)
        );
        raft.harvest(mockArk, mockRewardToken, bytes(""));

        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT,
            receiveAtLeast: REWARD_AMOUNT,
            withData: abi.encode()
        });

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
            address(mockToken),
            BALANCE_AFTER_SWAP
        );

        vm.prank(superKeeper);
        raft.swapAndBoard(mockArk, mockRewardToken, swapData);
    }

    function test_SwapAmountExceedsHarvested() public {
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk.harvest.selector,
                mockRewardToken,
                bytes("")
            ),
            abi.encode(REWARD_AMOUNT)
        );
        raft.harvest(mockArk, mockRewardToken, bytes(""));

        SwapData memory swapData = SwapData({
            fromAsset: mockRewardToken,
            amount: REWARD_AMOUNT + 1, // Exceeds harvested amount
            receiveAtLeast: REWARD_AMOUNT,
            withData: abi.encode()
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                SwapAmountExceedsHarvestedAmount.selector,
                REWARD_AMOUNT + 1,
                REWARD_AMOUNT,
                mockRewardToken
            )
        );

        vm.prank(superKeeper);
        raft.swapAndBoard(mockArk, mockRewardToken, swapData);
    }

    function test_SetSwapProvider() public {
        // Attempt to set new swap provider as non-superkeeper
        address notGovernor = address(0x123);
        vm.prank(notGovernor);
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotSuperKeeper.selector, notGovernor)
        );
        raft.setSwapProvider(newSwapProvider);

        // Set new swap provider as superkeeper
        vm.prank(superKeeper);
        raft.setSwapProvider(newSwapProvider);

        // Verify the swap provider has been updated
        assertEq(raft.swapProvider(), newSwapProvider);
    }

    function _setupMockCalls() internal {
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(
                IArk.harvest.selector,
                mockRewardToken,
                bytes("")
            ),
            abi.encode(REWARD_AMOUNT)
        );

        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(raft)),
            abi.encode(REWARD_AMOUNT)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(raft)),
            abi.encode(BALANCE_AFTER_SWAP)
        );

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

    function test() external {}
}
