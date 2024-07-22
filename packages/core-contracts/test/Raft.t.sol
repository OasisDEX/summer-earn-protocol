// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IArk} from "../src/interfaces/IArk.sol";
import {IRaftEvents} from "../src/interfaces/IRaftEvents.sol";
import {Raft} from "../src/contracts/Raft.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract RaftTest is Test, IRaftEvents {
    Raft public raft;

    address public constant governor = address(1);
    address public constant mockArk = address(5);
    address public constant mockSwapRouter = address(6);
    address public constant mockUniswapFactory = address(9);
    address public constant mockWETH = address(10);
    address public constant mockToken = address(7);
    address public constant keeper = address(8);

    function setUp() public {
        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        raft = new Raft(mockSwapRouter, mockUniswapFactory, mockWETH, address(accessManager));

        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);
    }

    function test_Harvest() public {
        address mockRewardToken = address(11);

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

        // Assert
        assertEq(raft.getHarvestedRewards(mockArk, mockRewardToken), 100);
    }

    function test_SwapAndBoard() public {
        // Arrange
        address mockRewardToken = address(11);
        uint256 rewardAmount = 100;
        uint256 balanceAfterSwap = 200;

        // Setup mock calls
        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk(mockArk).token.selector),
            abi.encode(mockToken)
        );

        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(raft)),
            abi.encode(rewardAmount)
        );

        vm.mockCall(
            mockRewardToken,
            abi.encodeWithSelector(IERC20.approve.selector, mockSwapRouter, rewardAmount),
            abi.encode(true)
        );

        // Mock Uniswap pool and factory calls
        address mockPool = address(12);
        vm.mockCall(
            mockUniswapFactory,
            abi.encodeWithSelector(IUniswapV3Factory.getPool.selector, mockRewardToken, mockWETH, 3000),
            abi.encode(mockPool)
        );

        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IUniswapV3Pool.token0.selector),
            abi.encode(mockRewardToken)
        );

        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IUniswapV3Pool.slot0.selector),
            abi.encode(uint160(1 << 96), 0, 0, 0, 0, 0, false)
        );

        vm.mockCall(
            mockSwapRouter,
            abi.encodeWithSelector(ISwapRouter.exactInput.selector),
            abi.encode(balanceAfterSwap)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(raft)),
            abi.encode(balanceAfterSwap)
        );

        vm.mockCall(
            mockToken,
            abi.encodeWithSelector(IERC20.approve.selector, mockArk, balanceAfterSwap),
            abi.encode(true)
        );

        vm.mockCall(
            mockArk,
            abi.encodeWithSelector(IArk.boardFromRaft.selector, balanceAfterSwap),
            abi.encode()
        );

        // Set harvested rewards
        vm.store(
            address(raft),
            keccak256(abi.encode(mockArk, keccak256(abi.encode(mockRewardToken, uint256(2))))),
            bytes32(uint256(rewardAmount))
        );

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit RewardSwapped(mockRewardToken, mockToken, rewardAmount, balanceAfterSwap);

        vm.expectEmit(true, true, true, true);
        emit RewardBoarded(mockArk, mockRewardToken, rewardAmount, balanceAfterSwap);

        // Act
        vm.prank(keeper);
        raft.swapAndBoard(mockArk, mockRewardToken);

        // Assert
        assertEq(raft.getHarvestedRewards(mockArk, mockRewardToken), 0);
    }

    function test_SetAllowedFeeTiers() public {
        // Arrange
        uint24[] memory newFeeTiers = new uint24[](3);
        newFeeTiers[0] = 100;
        newFeeTiers[1] = 500;
        newFeeTiers[2] = 3000;

        // Act
        vm.prank(governor);
        raft.setAllowedFeeTiers(newFeeTiers);

        // Assert
        assertEq(raft.allowedFeeTiers(0), 100);
        assertEq(raft.allowedFeeTiers(1), 500);
        assertEq(raft.allowedFeeTiers(2), 3000);
    }

    function test_GetPrice() public {
        // Arrange
        address tokenIn = address(13);
        address tokenOut = address(14);
        uint24[] memory fees = new uint24[](1);
        fees[0] = 3000;

        address mockPool = address(15);
        vm.mockCall(
            mockUniswapFactory,
            abi.encodeWithSelector(IUniswapV3Factory.getPool.selector, tokenIn, tokenOut, 3000),
            abi.encode(mockPool)
        );

        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IERC20.balanceOf.selector, mockPool),
            abi.encode(1000000)
        );

        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IUniswapV3Pool.token0.selector),
            abi.encode(tokenIn)
        );

        vm.mockCall(
            mockPool,
            abi.encodeWithSelector(IUniswapV3Pool.slot0.selector),
            abi.encode(uint160(1 << 96), 0, 0, 0, 0, 0, false)
        );

        vm.mockCall(
            tokenIn,
            abi.encodeWithSelector(IERC20.decimals.selector),
            abi.encode(18)
        );

        vm.mockCall(
            tokenOut,
            abi.encodeWithSelector(IERC20.decimals.selector),
            abi.encode(18)
        );

        // Act
        (uint256 price, uint24 fee) = raft.getPrice(tokenIn, tokenOut, fees);

        // Assert
        assertEq(price, 1 ether);
        assertEq(fee, 3000);
    }
}