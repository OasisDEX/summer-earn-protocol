// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderTestBase} from "./fleets/FleetCommanderTestBase.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdmiralsQuarters} from "../src/contracts/AdmiralsQuarters.sol";

interface IAggregationRouterV5 {
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(
        address executor,
        SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount);
}

contract MockOneInchRouter {
    function swap(
        address executor,
        IAggregationRouterV5.SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata data
    ) external payable returns (uint256 returnAmount, uint256 spentAmount) {
        IERC20(desc.srcToken).transferFrom(
            msg.sender,
            desc.dstReceiver,
            desc.amount
        );
        return (desc.amount, desc.amount); // 1:1 swap for simplicity
    }
}

contract AdmiralsQuartersTest is FleetCommanderTestBase {
    AdmiralsQuarters public admiralsQuarters;
    MockOneInchRouter public oneInchRouter;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);

        oneInchRouter = new MockOneInchRouter();
        admiralsQuarters = new AdmiralsQuarters(address(oneInchRouter));

        // Grant roles
        vm.startPrank(governor);
        accessManager.grantKeeperRole(address(this));
        vm.stopPrank();

        // Mint tokens for users
        mockToken.mint(user1, 1000e18);
        mockToken.mint(user2, 1000e18);

        // Approve AdmiralsQuarters to spend user tokens
        vm.prank(user1);
        mockToken.approve(address(admiralsQuarters), type(uint256).max);
        vm.prank(user2);
        mockToken.approve(address(admiralsQuarters), type(uint256).max);
    }

    function test_EnterFleets() public {
        uint256 depositAmount = 100e18;

        address[] memory fleets = new address[](1);
        fleets[0] = address(fleetCommander);

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 100; // 100% allocation to the single fleet

        bytes[] memory swapCalldatas = new bytes[](1);
        swapCalldatas[0] = "";

        vm.prank(user1);
        admiralsQuarters.enterFleets(
            fleets,
            allocations,
            IERC20(address(mockToken)),
            depositAmount,
            swapCalldatas
        );

        assertEq(
            fleetCommander.balanceOf(user1),
            depositAmount,
            "Incorrect balance after entering fleets"
        );
        assertEq(
            mockToken.balanceOf(address(bufferArk)),
            depositAmount,
            "Incorrect token balance in FleetCommander"
        );
    }

    function test_ExitFleets() public {
        uint256 user1BalanceBefore = mockToken.balanceOf(user1);
        uint256 depositAmount = 100e18;

        address[] memory fleets = new address[](1);
        fleets[0] = address(fleetCommander);

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 100; // 100% allocation to the single fleet

        bytes[] memory swapCalldatas = new bytes[](1);
        swapCalldatas[0] = "";

        // First, enter fleets
        vm.prank(user1);
        admiralsQuarters.enterFleets(
            fleets,
            allocations,
            IERC20(address(mockToken)),
            depositAmount,
            swapCalldatas
        );

        // Now exit fleets
        uint256[] memory shareAmounts = new uint256[](1);
        shareAmounts[0] = depositAmount;

        vm.startPrank(user1);
        fleetCommander.approve(address(admiralsQuarters), depositAmount);
        admiralsQuarters.exitFleets(
            fleets,
            shareAmounts,
            IERC20(address(mockToken)),
            depositAmount,
            swapCalldatas
        );
        vm.stopPrank();

        uint256 user1BalanceAfter = mockToken.balanceOf(user1);

        assertEq(
            fleetCommander.balanceOf(user1),
            0,
            "User balance should be 0 after exit"
        );
        assertEq(
            user1BalanceAfter,
            user1BalanceBefore,
            "User should receive original deposit amount"
        );
    }

    function test_MultiUserInteraction() public {
        uint256 user1BalanceBefore = mockToken.balanceOf(user1);
        uint256 user2BalanceBefore = mockToken.balanceOf(user2);
        uint256 user1DepositAmount = 100e18;
        uint256 user2DepositAmount = 200e18;

        address[] memory fleets = new address[](1);
        fleets[0] = address(fleetCommander);

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 100; // 100% allocation to the single fleet

        bytes[] memory swapCalldatas = new bytes[](1);
        swapCalldatas[0] = "";

        // User 1 enters fleets
        vm.prank(user1);
        admiralsQuarters.enterFleets(
            fleets,
            allocations,
            IERC20(address(mockToken)),
            user1DepositAmount,
            swapCalldatas
        );

        // User 2 enters fleets
        vm.prank(user2);
        admiralsQuarters.enterFleets(
            fleets,
            allocations,
            IERC20(address(mockToken)),
            user2DepositAmount,
            swapCalldatas
        );

        assertEq(
            fleetCommander.balanceOf(user1),
            user1DepositAmount,
            "Incorrect user1 balance"
        );
        assertEq(
            fleetCommander.balanceOf(user2),
            user2DepositAmount,
            "Incorrect user2 balance"
        );

        // User 1 exits fleets
        uint256[] memory user1ShareAmounts = new uint256[](1);
        user1ShareAmounts[0] = user1DepositAmount;

        vm.startPrank(user1);
        fleetCommander.approve(address(admiralsQuarters), user1DepositAmount);
        admiralsQuarters.exitFleets(
            fleets,
            user1ShareAmounts,
            IERC20(address(mockToken)),
            user1DepositAmount,
            swapCalldatas
        );
        vm.stopPrank();

        // User 2 exits fleets
        uint256[] memory user2ShareAmounts = new uint256[](1);
        user2ShareAmounts[0] = user2DepositAmount;

        vm.startPrank(user2);
        fleetCommander.approve(address(admiralsQuarters), user2DepositAmount);
        admiralsQuarters.exitFleets(
            fleets,
            user2ShareAmounts,
            IERC20(address(mockToken)),
            user2DepositAmount,
            swapCalldatas
        );
        vm.stopPrank();

        uint256 user1BalanceAfter = mockToken.balanceOf(user1);
        uint256 user2BalanceAfter = mockToken.balanceOf(user2);
        assertEq(
            fleetCommander.balanceOf(user1),
            0,
            "User1 balance should be 0 after exit"
        );
        assertEq(
            fleetCommander.balanceOf(user2),
            0,
            "User2 balance should be 0 after exit"
        );
        assertEq(
            user1BalanceBefore,
            user1BalanceAfter,
            "User1 should receive original deposit amount"
        );
        assertEq(
            user2BalanceBefore,
            user2BalanceAfter,
            "User2 should receive original deposit amount"
        );
    }
}
