// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {StakedSummerToken} from "../../src/contracts/StakedSummerToken.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/*
 * @title SummerStaking Core Tests
 * @dev Test contract for SummerStaking contract constructor and core functionality.
 */
contract SummerStakingCoreTest is SummerGovernorV2TestBase {
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    uint256 public constant STAKE_AMOUNT = 1000 ether;

    SummerStaking public aStaking;
    SummerStaking public bStaking;

    function setUp() public override {
        super.setUp();

        // Setup test users with tokens
        deal(address(aSummerToken), user1, STAKE_AMOUNT * 2);
        deal(address(aSummerToken), user2, STAKE_AMOUNT * 2);

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();

        aStaking = new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );
        bStaking = new SummerStaking(
            address(accessManagerB),
            address(bSummerToken),
            address(bxSumr)
        );
        vm.prank(address(timelockA));
        axSumr.setStakingModule(address(aStaking));
        vm.prank(address(timelockB));
        bxSumr.setStakingModule(address(bStaking));
    }

    // Helper function to create a fresh staking contract for isolated tests
    function createFreshStaking() internal returns (SummerStaking) {
        SummerStaking freshStaking = new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );

        // Set staking module so freshStaking can mint/burn StakedSummerToken
        vm.prank(address(timelockA));
        axSumr.setStakingModule(address(freshStaking));

        return freshStaking;
    }

    function test_Constructor_ValidParameters() public {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        SummerStaking newStaking = new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr)
        );

        assertEq(address(newStaking.SUMMER_TOKEN()), address(aSummerToken));
        assertEq(address(newStaking.STAKED_SUMMER_TOKEN()), address(axSumr));
    }

    function test_Constructor_ZeroProtocolAccessManager() public {
        vm.expectRevert(); // Should revert due to ProtocolAccessManaged constructor
        new SummerStaking(
            address(0), // Zero protocol access manager
            address(aSummerToken),
            address(axSumr)
        );
    }

    function test_Constructor_ZeroSummerToken() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Summer token address cannot be zero"
            )
        );
        new SummerStaking(
            address(accessManagerA),
            address(0), // Zero summer token
            address(axSumr)
        );
    }

    function test_Constructor_ZeroXSumr() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "StakedSummerToken address cannot be zero"
            )
        );
        new SummerStaking(
            address(accessManagerA),
            address(aSummerToken),
            address(0) // Zero StakedSummerToken
        );
    }

    function test_Stake_ValidAmount() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days;

        // Approve staking contract to spend tokens
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake tokens with lockup
        vm.prank(user1);
        aStaking.stakeWithLockup(stakeAmount, lockupPeriod);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);
    }

    function test_Stake_ZeroAmount() public {
        // Approve staking contract (even for zero amount)
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), 0);

        // Stake zero amount should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotStakeZero()"));
        aStaking.stakeWithLockup(0, 365 days);

        // Balances should remain unchanged
        assertEq(axSumr.balanceOf(user1), 0);
    }

    function test_Stake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;

        // Approve less than stake amount
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount - 1);

        // Attempt to stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // SafeERC20 will revert on insufficient allowance
        aStaking.stakeWithLockup(stakeAmount, 365 days);
    }

    function test_Stake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT * 10; // More than user has

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);

        // Attempt to stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // ERC20 will revert on insufficient balance
        aStaking.stakeWithLockup(stakeAmount, 365 days);
    }

    function test_Unstake_ValidAmount() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days;

        // First stake some tokens with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Approve staking contract to burn StakedSummerToken
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount);

        // Unstake tokens from specific stake (no penalty since lockup ended)
        vm.prank(user1);
        aStaking.unstakeFromStake(0, stakeAmount);

        // Check balances after unstaking - should get full amount back
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);
    }

    function test_Unstake_ZeroAmount() public {
        uint256 lockupPeriod = 365 days;

        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), STAKE_AMOUNT);
        aStaking.stakeWithLockup(STAKE_AMOUNT, lockupPeriod);
        vm.stopPrank();

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Unstake zero amount should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotUnstakeZero()"));
        aStaking.unstakeFromStake(0, 0);

        // StakedSummerToken balance should remain unchanged
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT);
    }

    function test_Unstake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days;

        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Approve less than unstake amount
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount - 1);

        // Attempt to unstake - should revert
        vm.prank(user1);
        vm.expectRevert(); // SafeERC20 will revert on insufficient allowance
        aStaking.unstakeFromStake(0, stakeAmount);
    }

    function test_Unstake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days;

        // First stake some tokens
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Approve staking contract
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount * 2);

        // Attempt to unstake more than available from specific stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // Will revert due to insufficient stake amount
        aStaking.unstakeFromStake(0, stakeAmount * 2);
    }

    function test_StakeUnstake_RoundTrip() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days;

        // Get initial balances
        uint256 initialSummerBalance = aSummerToken.balanceOf(user1);

        // Stake tokens with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);
        aStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Verify staking worked
        assertEq(axSumr.balanceOf(user1), stakeAmount);
        assertEq(
            aSummerToken.balanceOf(user1),
            initialSummerBalance - stakeAmount
        );

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Unstake tokens from specific stake
        vm.startPrank(user1);
        axSumr.approve(address(aStaking), stakeAmount);
        aStaking.unstakeFromStake(0, stakeAmount);
        vm.stopPrank();

        // Verify round trip worked - should get full amount back (no penalty)
        assertEq(axSumr.balanceOf(user1), 0);
        assertEq(aSummerToken.balanceOf(user1), initialSummerBalance);
    }

    function test_StakeWithLockup_ValidLockupPeriod() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 365 days; // 1 year

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake with lockup
        vm.prank(user1);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);

        // Check stake details
        (uint256 amount, uint256 weightedAmount, uint256 lockupEndTime, uint256 lockupPeriodStored) =
            freshStaking.getUserStake(user1, 0);

        assertEq(amount, stakeAmount);
        assertEq(lockupEndTime, block.timestamp + lockupPeriod);
        assertEq(lockupPeriodStored, lockupPeriod);
        assertGt(weightedAmount, stakeAmount); // Weighted amount should be higher
    }

    function test_StakeWithLockup_ZeroLockupPeriod() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);

        // Stake with zero lockup
        vm.prank(user1);
        freshStaking.stakeWithLockup(stakeAmount, 0);

        // Check stake details - weighted amount should equal actual amount
        (uint256 amount, uint256 weightedAmount, , ) = freshStaking.getUserStake(user1, 0);
        assertEq(amount, stakeAmount);
        assertEq(weightedAmount, stakeAmount); // No weighting for 0 lockup
    }

    function test_StakeWithLockup_InvalidLockupPeriod() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 invalidLockupPeriod = 5 * 365 days; // 5 years - exceeds max

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);

        // Attempt to stake with invalid lockup period
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period cannot exceed 4 years"
            )
        );
        freshStaking.stakeWithLockup(stakeAmount, invalidLockupPeriod);
    }

    function test_StakeWithLockup_ZeroAmount() public {
        SummerStaking freshStaking = createFreshStaking();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotStakeZero()"));
        freshStaking.stakeWithLockup(0, 365 days);
    }

    function test_WeightedStakeCalculation() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;

        // Test different lockup periods
        uint256[] memory lockupPeriods = new uint256[](4);
        lockupPeriods[0] = 0;           // No lockup
        lockupPeriods[1] = 365 days;    // 1 year
        lockupPeriods[2] = 2 * 365 days; // 2 years
        lockupPeriods[3] = 4 * 365 days; // 4 years (max)

        for (uint256 i = 0; i < lockupPeriods.length; i++) {
            vm.startPrank(user1);
            aSummerToken.approve(address(freshStaking), stakeAmount);
            freshStaking.stakeWithLockup(stakeAmount, lockupPeriods[i]);
            vm.stopPrank();

            (, uint256 weightedAmount, , ) = freshStaking.getUserStake(user1, i);

            if (lockupPeriods[i] == 0) {
                assertEq(weightedAmount, stakeAmount);
            } else {
                assertGt(weightedAmount, stakeAmount);
                // Verify the formula: amount * (4E-16 * time^2 + 0.05)
                uint256 expectedWeightedAmount = freshStaking.calculateWeightedStake(stakeAmount, lockupPeriods[i]);
                assertEq(weightedAmount, expectedWeightedAmount);
            }
        }
    }

    function test_BalanceOf_ReturnsWeightedAmount() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 2 * 365 days;

        // Stake with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // balanceOf should return weighted amount, not actual amount
        uint256 balanceOf = freshStaking.balanceOf(user1);
        uint256 actualBalance = freshStaking.actualBalanceOf(user1);

        assertGt(balanceOf, actualBalance); // Weighted > Actual
        assertEq(actualBalance, stakeAmount); // Actual = staked amount

        (, uint256 expectedWeightedAmount, , ) = freshStaking.getUserStake(user1, 0);
        assertEq(balanceOf, expectedWeightedAmount);
    }

    function test_CalculatePenalty_NoPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 365 days;

        // Stake with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Penalty should be 0
        uint256 penalty = freshStaking.calculatePenalty(user1, 0);
        assertEq(penalty, 0);
    }

    function test_CalculatePenalty_WithPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 365 days;

        // Stake with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward halfway through lockup
        vm.warp(block.timestamp + lockupPeriod / 2);

        // Penalty should be half of weighted amount
        uint256 penalty = freshStaking.calculatePenalty(user1, 0);
        (, uint256 weightedAmount, , ) = freshStaking.getUserStake(user1, 0);

        assertEq(penalty, weightedAmount / 2);
    }

    function test_UnstakeFromStake_NoPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 365 days;

        // Stake with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake from specific stake - should get full amount back
        vm.prank(user1);
        axSumr.approve(address(freshStaking), stakeAmount);
        freshStaking.unstakeFromStake(0, stakeAmount);

        // Check balances - should get full amount back (no penalty)
        assertEq(aSummerToken.balanceOf(user1), userSummerBalanceBefore + stakeAmount);
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);

        // Stake should be removed
        vm.expectRevert();
        freshStaking.getUserStake(user1, 0);
    }

    function test_UnstakeFromStake_WithPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 365 days;

        // Stake with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward halfway through lockup
        vm.warp(block.timestamp + lockupPeriod / 2);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Calculate expected penalty
        uint256 expectedPenalty = freshStaking.calculatePenalty(user1, 0);
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Unstake from specific stake
        vm.prank(user1);
        axSumr.approve(address(freshStaking), stakeAmount);
        freshStaking.unstakeFromStake(0, stakeAmount);

        // Check balances - should get penalized amount back
        assertEq(aSummerToken.balanceOf(user1), userSummerBalanceBefore + expectedReturnAmount);
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);
    }

    function test_UnstakeFromStake_PartialUnstake() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 unstakeAmount = 300 ether;
        uint256 lockupPeriod = 365 days;

        // Stake with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);
        freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
        vm.stopPrank();

        // Fast forward halfway through lockup
        vm.warp(block.timestamp + lockupPeriod / 2);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Calculate expected penalty for partial unstake
        uint256 fullPenalty = freshStaking.calculatePenalty(user1, 0);
        uint256 expectedPenalty = (fullPenalty * unstakeAmount) / stakeAmount;
        uint256 expectedReturnAmount = unstakeAmount - expectedPenalty;

        // Partial unstake from specific stake
        vm.prank(user1);
        axSumr.approve(address(freshStaking), unstakeAmount);
        freshStaking.unstakeFromStake(0, unstakeAmount);

        // Check balances
        assertEq(aSummerToken.balanceOf(user1), userSummerBalanceBefore + expectedReturnAmount);
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - unstakeAmount);

        // Check remaining stake
        (uint256 remainingAmount, , , ) = freshStaking.getUserStake(user1, 0);
        assertEq(remainingAmount, stakeAmount - unstakeAmount);
    }

    function test_Unstake_ProportionalUnstaking() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount1 = 1000 ether;
        uint256 stakeAmount2 = 500 ether;
        uint256 lockupPeriod1 = 365 days;
        uint256 lockupPeriod2 = 730 days; // 2 years

        // Stake two different amounts with different lockup periods
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount1 + stakeAmount2);
        freshStaking.stakeWithLockup(stakeAmount1, lockupPeriod1);
        freshStaking.stakeWithLockup(stakeAmount2, lockupPeriod2);
        vm.stopPrank();

        // Fast forward halfway through first lockup
        vm.warp(block.timestamp + lockupPeriod1 / 2);

        uint256 totalStaked = stakeAmount1 + stakeAmount2;
        uint256 unstakeAmount = 800 ether; // Unstake 800 out of 1500 total

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Proportional unstake
        vm.prank(user1);
        axSumr.approve(address(freshStaking), unstakeAmount);
        freshStaking.unstake(unstakeAmount);

        // Check balances
        assertLt(aSummerToken.balanceOf(user1), userSummerBalanceBefore + unstakeAmount); // Less due to penalties
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - unstakeAmount);
    }

    function test_Stake_DirectStakeReverts() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount);

        // Direct stake should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_DirectStakeNotAllowed(string)",
                "Use stakeWithLockup instead"
            )
        );
        freshStaking.stake(stakeAmount);
    }

    function test_MultipleUsers_StakeSeparately() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStaking();

        uint256 stakeAmount1 = STAKE_AMOUNT;
        uint256 stakeAmount2 = STAKE_AMOUNT / 2;

        // User 1 stakes with lockup
        vm.startPrank(user1);
        aSummerToken.approve(address(freshStaking), stakeAmount1);
        freshStaking.stakeWithLockup(stakeAmount1, 365 days);
        vm.stopPrank();

        // User 2 stakes with lockup
        vm.startPrank(user2);
        aSummerToken.approve(address(freshStaking), stakeAmount2);
        freshStaking.stakeWithLockup(stakeAmount2, 730 days);
        vm.stopPrank();

        // Verify both users have correct balances
        assertEq(axSumr.balanceOf(user1), stakeAmount1);
        assertEq(axSumr.balanceOf(user2), stakeAmount2);

        // Verify weighted balances are different due to different lockup periods
        uint256 balance1 = freshStaking.balanceOf(user1);
        uint256 balance2 = freshStaking.balanceOf(user2);
        assertGt(balance1, stakeAmount1); // User 1 has 1 year lockup
        assertGt(balance2, stakeAmount2); // User 2 has 2 year lockup
        assertGt(balance2, balance1);     // User 2 has higher weighted balance
    }

    function test_StakeUnstake_MultipleRounds() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStaking();

        uint256 stakeAmount = STAKE_AMOUNT / 4;
        uint256 lockupPeriod = 365 days;

        // Stake multiple times with lockup
        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(user1);
            aSummerToken.approve(address(freshStaking), stakeAmount);
            freshStaking.stakeWithLockup(stakeAmount, lockupPeriod);
            vm.stopPrank();
        }

        // Verify accumulated staking
        assertEq(axSumr.balanceOf(user1), stakeAmount * 4);
        // Note: Contract balance will be 0 since tokens are wrapped

        // Fast forward past lockup period
        vm.warp(block.timestamp + lockupPeriod + 1);

        // Unstake multiple times (unstake from specific stakes)
        for (uint256 i = 0; i < 4; i++) {
            vm.startPrank(user1);
            axSumr.approve(address(freshStaking), stakeAmount);
            freshStaking.unstakeFromStake(0, stakeAmount); // Unstake from first remaining stake
            vm.stopPrank();
        }

        // Verify final balances
        assertEq(axSumr.balanceOf(user1), 0);
    }
}
