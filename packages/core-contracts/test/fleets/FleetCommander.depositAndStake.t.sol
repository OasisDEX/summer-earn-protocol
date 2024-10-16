// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";

import {IStakingRewardsManager} from "../../src/interfaces/IStakingRewardsManager.sol";
import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DepositAndStakeTest is Test, TestHelpers, FleetCommanderTestBase {
    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant MAX_DEPOSIT_CAP = 100000 * 10 ** 6;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
        fleetCommanderStorageWriter.setDepositCap(MAX_DEPOSIT_CAP);
    }

    function test_DepositWithStake() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        _mockArkTotalAssets(ark1, 0);
        _mockArkTotalAssets(ark2, 0);
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(amount)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "FleetCommander balance should be zero"
        );
        assertEq(
            stakingRewardsManager.balanceOf(mockUser),
            amount,
            "StakingRewardsManager balance should match deposit amount"
        );
    }

    function test_DepositWithStakeZeroAmount() public {
        vm.expectRevert(abi.encodeWithSignature("CannotStakeZero()"));
        vm.prank(mockUser);
        fleetCommander.depositAndStake(0, mockUser);
    }

    function test_DepositWithStakeToOtherReceiver() public {
        address receiver = address(0xdeadbeef);
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        vm.stopPrank();

        vm.startPrank(receiver);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(amount)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.depositAndStake(amount, receiver);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(receiver),
            0,
            "FleetCommander: Receiver shares should be with StakingRewardsManager"
        );
        assertEq(
            stakingRewardsManager.balanceOf(receiver),
            amount,
            "StakingRewardsManager: Receiver should have received the staked amount"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "FleetCommander: Depositor should not have received any shares"
        );
        assertEq(
            stakingRewardsManager.balanceOf(mockUser),
            0,
            "StakingRewardsManager: Depositor should not have any staked amount"
        );
    }

    function test_DepositWithStakeMultipleTimes() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount * 3);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount * 3);

        vm.startPrank(mockUser);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(amount * 3)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "FleetCommander: User should have zero shares after staking"
        );
        assertEq(
            stakingRewardsManager.balanceOf(mockUser),
            amount * 3,
            "StakingRewardsManager: User should have correct total staked amount"
        );
    }

    function test_DepositAndStakeExceedingAllowance() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 allowance = amount / 2;

        mockToken.mint(mockUser, amount);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), allowance);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(fleetCommander),
                allowance,
                amount
            )
        );
        vm.prank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
    }

    function test_DepositWithStakeExceedingBalance() public {
        uint256 amount = DEPOSIT_AMOUNT;
        uint256 balance = amount / 2;

        mockToken.mint(mockUser, balance);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxDeposit(address,uint256,uint256)",
                mockUser,
                amount,
                balance
            )
        );
        vm.prank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
    }

    function test_DepositWithStakeUpToDepositCap() public {
        uint256 depositCap = MAX_DEPOSIT_CAP / 2;
        fleetCommanderStorageWriter.setDepositCap(depositCap);
        mockToken.mint(mockUser, depositCap);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), depositCap);
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(depositCap)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.depositAndStake(depositCap, mockUser);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "FleetCommander: User should have zero shares after staking"
        );
        assertEq(
            stakingRewardsManager.balanceOf(mockUser),
            depositCap,
            "StakingRewardsManager: User should have correct staked amount"
        );
    }

    function test_DepositAndStakeExceedingDepositCap() public {
        uint256 depositCap = MAX_DEPOSIT_CAP / 2;
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        uint256 amount = depositCap + 1;
        mockToken.mint(mockUser, amount);
        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxDeposit(address,uint256,uint256)",
                mockUser,
                amount,
                depositCap
            )
        );
        vm.prank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
    }

    function test_DepositAndStakeEventEmission() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.startPrank(mockUser);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(amount)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        vm.expectEmit(true, true, true, true);
        emit IERC4626.Deposit(mockUser, mockUser, amount, amount);
        vm.expectEmit(true, true, true, true);
        emit IStakingRewardsManager.Staked(mockUser, amount);
        fleetCommander.depositAndStake(amount, mockUser);

        vm.stopPrank();
    }

    function test_DepositAndStakeUpdatesBufferBalance() public {
        uint256 amount = DEPOSIT_AMOUNT;
        mockToken.mint(mockUser, amount);

        FleetConfig memory config = fleetCommander.getConfig();
        uint256 initialBufferBalance = config.bufferArk.totalAssets();

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.startPrank(mockUser);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(amount)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
        vm.stopPrank();

        uint256 finalBufferBalance = bufferArk.totalAssets();
        assertEq(
            finalBufferBalance,
            initialBufferBalance + amount,
            "Buffer balance should increase by deposited amount"
        );
    }

    function testFuzz_DepositAndStake(uint256 amount) public {
        FleetConfig memory config = fleetCommander.getConfig();
        vm.assume(amount > 0 && amount <= config.depositCap);

        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);

        vm.startPrank(mockUser);
        fleetCommander.approve(
            address(stakingRewardsManager),
            fleetCommander.convertToShares(amount)
        );
        vm.stopPrank();

        vm.startPrank(mockUser);
        fleetCommander.depositAndStake(amount, mockUser);
        vm.stopPrank();

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "FleetCommander balance should match deposit amount"
        );
        assertEq(
            stakingRewardsManager.balanceOf(mockUser),
            amount,
            "StakingRewardsManager balance should match deposit amount"
        );
    }
}
