// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletFactoryV2} from "../../src/interfaces/ISummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract SummerVestingWalletFactoryV2Test is Test {
    SummerVestingWalletFactoryV2 public factory;
    MockERC20 public token;
    address public foundation;
    address public beneficiary;

    event VestingWalletCreated(
        address indexed beneficiary,
        address indexed vestingWallet,
        ISummerVestingWalletV2.VestingParams vestingParams,
        uint256 performanceGoalsCount
    );

    function setUp() public {
        foundation = makeAddr("foundation");
        beneficiary = makeAddr("beneficiary");

        // Deploy mock token
        token = new MockERC20();

        // Deploy factory (foundation is initial owner)
        factory = new SummerVestingWalletFactoryV2(
            address(token),
            foundation // foundation is the owner
        );
    }

    function test_RevertIf_ZeroTokenAddress() public {
        vm.expectRevert(
            ISummerVestingWalletFactoryV2.ZeroTokenAddress.selector
        );
        new SummerVestingWalletFactoryV2(address(0), foundation);
    }

    function test_CreateVestingWallet() public {
        // Setup parameters
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: 1000 ether,
                vestingPeriods: 12,
                totalVestingAmount: 2000 ether
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                1
            );
        performanceGoals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: 500 ether,
            description: "Test goal",
            reached: false
        });

        uint256 totalAmount = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount +
            performanceGoals[0].amount;

        // Mint tokens to foundation and approve factory
        deal(address(token), foundation, totalAmount);
        vm.startPrank(foundation);
        token.approve(address(factory), totalAmount);

        // Create vesting wallet
        address vestingWallet = factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();

        // Verify mappings
        assertEq(factory.vestingWallets(beneficiary), vestingWallet);
        assertEq(factory.vestingWalletOwners(vestingWallet), beneficiary);

        // Verify token transfer
        assertEq(token.balanceOf(vestingWallet), totalAmount);
    }

    function test_RevertIf_VestingWalletAlreadyExists() public {
        // Setup
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: 1000 ether,
                vestingPeriods: 12,
                totalVestingAmount: 2000 ether
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                0
            );

        uint256 totalAmount = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount;

        // Create first vesting wallet
        deal(address(token), foundation, totalAmount * 2);
        vm.startPrank(foundation);
        token.approve(address(factory), totalAmount * 2);
        factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );

        // Attempt to create second vesting wallet
        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactoryV2
                    .VestingWalletAlreadyExists
                    .selector,
                beneficiary
            )
        );
        factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();
    }

    function test_RevertIf_InsufficientAllowance() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: 1000 ether,
                vestingPeriods: 12,
                totalVestingAmount: 2000 ether
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                0
            );

        uint256 totalAmount = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount;

        deal(address(token), foundation, totalAmount);
        vm.startPrank(foundation);
        token.approve(address(factory), totalAmount / 2); // Approve less than required

        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactoryV2.InsufficientAllowance.selector,
                totalAmount,
                totalAmount / 2
            )
        );
        factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();
    }

    function test_RevertIf_InsufficientBalance() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: 1000 ether,
                vestingPeriods: 12,
                totalVestingAmount: 2000 ether
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                0
            );

        uint256 totalAmount = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount;

        deal(address(token), foundation, totalAmount / 2); // Mint less than required
        vm.startPrank(foundation);
        token.approve(address(factory), totalAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISummerVestingWalletFactoryV2.InsufficientBalance.selector,
                totalAmount,
                totalAmount / 2
            )
        );
        factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();
    }

    function test_CreateVestingWalletWithMultiplePerformanceGoals() public {
        // Setup parameters with multiple performance goals
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: 2000006 ether,
                vestingPeriods: 18,
                totalVestingAmount: 5999994 ether
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                2
            );
        performanceGoals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: 1000000 ether,
            description: "500M TVL",
            reached: false
        });
        performanceGoals[1] = ISummerVestingWalletV2.PerformanceGoal({
            amount: 1000000 ether,
            description: "100,000 active users",
            reached: false
        });

        uint256 totalAmount = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount +
            performanceGoals[0].amount +
            performanceGoals[1].amount;

        // Mint tokens to foundation and approve factory
        deal(address(token), foundation, totalAmount);
        vm.startPrank(foundation);
        token.approve(address(factory), totalAmount);

        // We can't predict the exact address, so we'll just check that the event was emitted
        vm.expectEmit(true, false, false, true);
        emit VestingWalletCreated(beneficiary, address(0), vestingParams, 2);

        // Create vesting wallet
        address vestingWallet = factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();

        // Verify total amount transferred
        assertEq(token.balanceOf(vestingWallet), totalAmount);
        assertEq(factory.vestingWallets(beneficiary), vestingWallet);
    }

    function test_EmptyPerformanceGoals() public {
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: 1000 ether,
                vestingPeriods: 12,
                totalVestingAmount: 2000 ether
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                0
            );

        uint256 totalAmount = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount;

        deal(address(token), foundation, totalAmount);
        vm.startPrank(foundation);
        token.approve(address(factory), totalAmount);

        address vestingWallet = factory.createVestingWallet(
            beneficiary,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();

        assertEq(token.balanceOf(vestingWallet), totalAmount);
    }

    function test_TokenAddress() public {
        assertEq(factory.token(), address(token));
    }
}
