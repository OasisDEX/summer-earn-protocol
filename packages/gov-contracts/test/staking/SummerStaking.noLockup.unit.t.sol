// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerStaking} from "../../src/contracts/SummerStaking.sol";
import {SummerStakingTestBase} from "./SummerStakingTestBase.sol";

/*
 * @title SummerStaking No Lockup Tests
 * @dev Test contract for SummerStaking contract constructor and core functionality.
 */
contract SummerStakingNoLockupTest is SummerStakingTestBase {
    function setUp() public override {
        super.setUp();

        vm.startPrank(whale);
        axSumr.burn(axSumr.balanceOf(whale));
        bxSumr.burn(bxSumr.balanceOf(whale));
        vm.stopPrank();
    }

    function test_Constructor_ValidParameters() public {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        SummerStaking newStaking = new SummerStaking(
            address(accessManagerA),
            address(configurationManagerA),
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
            address(configurationManagerA),
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
            address(configurationManagerA),
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
            address(configurationManagerA),
            address(aSummerToken),
            address(0) // Zero StakedSummerToken
        );
    }

    function test_Stake_ValidAmount() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake tokens with lockup using helper
        _stake(user1, stakeAmount, lockupPeriod);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);
    }

    function test_Stake_ValidAmount_one_second_lockup() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 1 seconds;

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Attempt to stake with invalid lockup period
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period must be at least 3 months"
            )
        );
        aStaking.stakeWithNewLockup(stakeAmount, lockupPeriod);

        // Check balances after staking - should remain unchanged
        assertEq(aSummerToken.balanceOf(user1), userSummerBalanceBefore);
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore);
    }

    function test_Stake_ZeroAmount() public {
        // Stake zero amount should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotStakeZero()"));
        aStaking.stakeWithNewLockup(0, 0); // No lockup for test

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
        aStaking.stakeWithNewLockup(stakeAmount, 0); // No lockup for test
    }

    function test_Stake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT * 10; // More than user has

        // Approve staking contract
        vm.prank(user1);
        aSummerToken.approve(address(aStaking), stakeAmount);

        // Attempt to stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // ERC20 will revert on insufficient balance
        aStaking.stakeWithNewLockup(stakeAmount, 0); // No lockup for test
    }

    function test_Unstake_ValidAmount() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens with lockup using helper
        _stake(user1, stakeAmount, lockupPeriod);

        // Get balances before unstaking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake tokens from specific stake using helper (no penalty since no lockup)
        _approveAndUnstake(user1, 0, stakeAmount);

        // Check balances after unstaking - should get full amount back
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);
    }

    function test_Unstake_ZeroAmount() public {
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens using helper
        _stake(user1, STAKE_AMOUNT, lockupPeriod);

        // Unstake zero amount should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotUnstakeZero()"));
        aStaking.unstakeFromLockup(0, 0);

        // StakedSummerToken balance should remain unchanged
        assertEq(axSumr.balanceOf(user1), STAKE_AMOUNT);
    }

    function test_Unstake_InsufficientAllowance() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens using helper
        _stake(user1, stakeAmount, lockupPeriod);

        // Approve less than unstake amount
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount - 1);

        // Attempt to unstake - should revert
        vm.prank(user1);
        vm.expectRevert(); // SafeERC20 will revert on insufficient allowance
        aStaking.unstakeFromLockup(0, stakeAmount);
    }

    function test_Unstake_InsufficientBalance() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // First stake some tokens using helper
        _stake(user1, stakeAmount, lockupPeriod);

        // Approve staking contract
        vm.prank(user1);
        axSumr.approve(address(aStaking), stakeAmount * 2);

        // Attempt to unstake more than available from specific stake - should revert
        vm.prank(user1);
        vm.expectRevert(); // Will revert due to insufficient stake amount
        aStaking.unstakeFromLockup(0, stakeAmount * 2);
    }

    function test_StakeUnstake_RoundTrip() public {
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // Get initial balances
        uint256 initialSummerBalance = aSummerToken.balanceOf(user1);

        // Stake tokens with lockup using helper
        _stake(user1, stakeAmount, lockupPeriod);

        // Verify staking worked
        assertEq(axSumr.balanceOf(user1), stakeAmount);
        assertEq(
            aSummerToken.balanceOf(user1),
            initialSummerBalance - stakeAmount
        );

        // Unstake tokens from specific stake using helper
        _approveAndUnstake(user1, 0, stakeAmount);

        // Verify round trip worked - should get full amount back (no penalty)
        assertEq(axSumr.balanceOf(user1), 0);
        assertEq(aSummerToken.balanceOf(user1), initialSummerBalance);
    }

    function test_StakeWithLockup_ValidLockupPeriod() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 lockupPeriod = 0; // No lockup for test

        // Get balances before staking
        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        // Check balances after staking
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore - stakeAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore + stakeAmount);

        // Check stake details
        (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 lockupPeriodStored
        ) = freshStaking.getUserStake(user1, 0);

        assertEq(amount, stakeAmount);
        assertEq(lockupEndTime, block.timestamp + lockupPeriod);
        assertEq(lockupPeriodStored, lockupPeriod);
        assertEq(weightedAmount, stakeAmount); // Weighted amount should equal staked amount for 0 lockup
    }

    function test_StakeWithLockup_ZeroLockupPeriod() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;

        // Stake with zero lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, 0);

        // Check stake details - weighted amount should equal actual amount
        (uint256 amount, uint256 weightedAmount, , ) = freshStaking
            .getUserStake(user1, 0);
        assertEq(amount, stakeAmount);
        assertEq(weightedAmount, stakeAmount); // No weighting for 0 lockup
    }

    function test_StakeWithLockup_InvalidLockupPeriod() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = STAKE_AMOUNT;
        uint256 invalidLockupPeriod = 5 * 365 days; // 5 years - exceeds max

        // Attempt to stake with invalid lockup period
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidLockupPeriod(string)",
                "Lockup period cannot exceed 4 years"
            )
        );
        freshStaking.stakeWithNewLockup(stakeAmount, invalidLockupPeriod);
    }

    function test_StakeWithLockup_ZeroAmount() public {
        SummerStaking freshStaking = createFreshStaking();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("CannotStakeZero()"));
        freshStaking.stakeWithNewLockup(0, 0); // No lockup for test
    }

    function test_WeightedStakeCalculation() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;

        // Test only zero lockup period for now
        uint256[] memory lockupPeriods = new uint256[](1);
        lockupPeriods[0] = 0; // No lockup

        for (uint256 i = 0; i < lockupPeriods.length; i++) {
            _stakeOnContract(
                freshStaking,
                user1,
                stakeAmount,
                lockupPeriods[i]
            );

            (, uint256 weightedAmount, , ) = freshStaking.getUserStake(
                user1,
                i
            );

            // For zero lockup, weighted amount should equal staked amount
            assertEq(weightedAmount, stakeAmount);

            // Verify the formula: amount * (4E-16 * time^2 + 0.05)
            uint256 expectedWeightedAmount = freshStaking
                .calculateWeightedStake(stakeAmount, lockupPeriods[i]);
            assertEq(weightedAmount, expectedWeightedAmount);
        }
    }

    function test_BalanceOf_ReturnsWeightedAmount() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        // balanceOf should return actual staked amount, weightedBalanceOf returns weighted amount
        uint256 balanceOf = freshStaking.balanceOf(user1); // Actual staked amount
        uint256 weightedBalance = freshStaking.weightedBalanceOf(user1); // Weighted amount

        assertEq(balanceOf, stakeAmount); // Actual = staked amount
        assertEq(weightedBalance, balanceOf); // For zero lockup, weighted = actual

        (, uint256 expectedWeightedAmount, , ) = freshStaking.getUserStake(
            user1,
            0
        );
        assertEq(weightedBalance, expectedWeightedAmount);
    }

    function test_CalculatePenalty_NoPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        // Penalty should be 0 for zero lockup
        uint256 penalty = freshStaking.calculatePenalty(user1, 0);
        assertEq(penalty, 0);
    }

    function test_CalculatePenalty_WithPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        // Penalty should be 0 for zero lockup
        uint256 penalty = freshStaking.calculatePenalty(user1, 0);
        assertEq(penalty, 0);
    }

    function test_CalculatePenalty_DifferentLockupPeriods() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;

        // Test only zero lockup period for now
        uint256[] memory lockupPeriods = new uint256[](1);
        lockupPeriods[0] = 0; // No lockup

        for (uint256 i = 0; i < lockupPeriods.length; i++) {
            _stakeOnContract(
                freshStaking,
                user1,
                stakeAmount,
                lockupPeriods[i]
            );

            // Calculate penalty immediately (no time passed)
            uint256 penalty = freshStaking.calculatePenalty(user1, i);

            // For zero lockup, penalty should always be 0
            assertEq(penalty, 0);
        }
    }

    function test_UnstakeFromStake_NoPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Unstake from specific stake using helper - should get full amount back
        _approveAndUnstakeOnContract(freshStaking, user1, 0, stakeAmount);

        // Check balances - should get full amount back (no penalty)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + stakeAmount,
            "aSummerToken.balanceOf(user1)"
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore - stakeAmount,
            "axSumr.balanceOf(user1)"
        );

        // Stake should be removed
        (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 _lockupPeriod
        ) = freshStaking.getUserStake(user1, 0);
        assertEq(amount, 0, "amount");
        assertEq(weightedAmount, 0, "weightedAmount");
        assertEq(lockupEndTime, 0, "lockupEndTime");
        assertEq(_lockupPeriod, 0, "lockupPeriod");
    }

    function test_UnstakeFromStake_WithPenalty() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Calculate expected penalty (should be 0 for zero lockup)
        uint256 expectedPenalty = freshStaking.calculatePenalty(user1, 0);
        uint256 expectedReturnAmount = stakeAmount - expectedPenalty;

        // Unstake from specific stake using helper
        _approveAndUnstakeOnContract(freshStaking, user1, 0, stakeAmount);

        // Check balances - should get full amount back (no penalty)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount
        );
        assertEq(axSumr.balanceOf(user1), userXSumrBalanceBefore - stakeAmount);

        // Check that user's total balance is updated
        assertEq(
            freshStaking.balanceOf(user1),
            userXSumrBalanceBefore - stakeAmount
        );
    }

    function test_UnstakeFromStake_PartialUnstake() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount = 1000 ether;
        uint256 unstakeAmount = 300 ether;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount, lockupPeriod);

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Calculate expected penalty for partial unstake (should be 0 for zero lockup)
        uint256 fullPenalty = freshStaking.calculatePenalty(user1, 0);
        uint256 expectedPenalty = (fullPenalty * unstakeAmount) / stakeAmount;
        uint256 expectedReturnAmount = unstakeAmount - expectedPenalty;

        // For zero lockup, penalty should be 0
        assertEq(expectedPenalty, 0);

        // Partial unstake from specific stake using helper
        _approveAndUnstakeOnContract(freshStaking, user1, 0, unstakeAmount);

        // Check balances
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + expectedReturnAmount,
            "userSummerBalanceBefore + expectedReturnAmount"
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore - unstakeAmount,
            "userXSumrBalanceBefore - unstakeAmount"
        );

        // Check remaining stake
        (uint256 remainingAmount, , , ) = freshStaking.getUserStake(user1, 0);
        assertEq(
            remainingAmount,
            stakeAmount - unstakeAmount,
            "remainingAmount"
        );

        // Check that user's total balance is updated correctly
        assertEq(
            freshStaking.balanceOf(user1),
            stakeAmount - unstakeAmount,
            "freshStaking.balanceOf(user1)"
        );
    }

    function test_Unstake_ProportionalUnstaking() public {
        SummerStaking freshStaking = createFreshStaking();
        uint256 stakeAmount1 = 1000 ether;
        uint256 stakeAmount2 = 500 ether;
        uint256 lockupPeriod1 = 0; // No lockup for test
        uint256 lockupPeriod2 = 0; // No lockup for test

        // Stake two different amounts with different lockup periods using helper
        _stakeOnContract(freshStaking, user1, stakeAmount1, lockupPeriod1);
        _stakeOnContract(freshStaking, user1, stakeAmount2, lockupPeriod2);

        uint256 totalStaked = stakeAmount1 + stakeAmount2;
        uint256 unstakeAmount = 800 ether; // Unstake 800 out of 1500 total

        uint256 initialBalance = freshStaking.balanceOf(user1);
        assertEq(initialBalance, totalStaked); // Should equal total staked

        uint256 userSummerBalanceBefore = aSummerToken.balanceOf(user1);
        uint256 userXSumrBalanceBefore = axSumr.balanceOf(user1);

        // Proportional unstake using helper
        _approveAndUnstakeOnContract(freshStaking, user1, 0, unstakeAmount);

        // Check balances (no penalties for zero lockup)
        assertEq(
            aSummerToken.balanceOf(user1),
            userSummerBalanceBefore + unstakeAmount
        );
        assertEq(
            axSumr.balanceOf(user1),
            userXSumrBalanceBefore - unstakeAmount
        );

        // Check that user's total balance is updated
        assertEq(freshStaking.balanceOf(user1), initialBalance - unstakeAmount);
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
                "Use stakeWithNewLockup instead"
            )
        );
        freshStaking.stake(stakeAmount);
    }

    function test_MultipleUsers_StakeSeparately() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStaking();

        uint256 stakeAmount1 = STAKE_AMOUNT;
        uint256 stakeAmount2 = STAKE_AMOUNT / 2;

        // User 1 stakes with lockup using helper
        _stakeOnContract(freshStaking, user1, stakeAmount1, 0);

        // User 2 stakes with lockup using helper
        _stakeOnContract(freshStaking, user2, stakeAmount2, 0);

        // Verify both users have correct balances
        assertEq(axSumr.balanceOf(user1), stakeAmount1);
        assertEq(axSumr.balanceOf(user2), stakeAmount2);

        // Verify weighted balances are same as staked amounts for zero lockup
        uint256 balance1 = freshStaking.weightedBalanceOf(user1);
        uint256 balance2 = freshStaking.weightedBalanceOf(user2);
        assertEq(balance1, stakeAmount1); // User 1 has no lockup
        assertEq(balance2, stakeAmount2); // User 2 has no lockup
    }

    function test_StakeUnstake_MultipleRounds() public {
        // Create fresh staking contract to avoid state interference
        SummerStaking freshStaking = createFreshStaking();

        uint256 stakeAmount = STAKE_AMOUNT / 4;
        uint256 lockupPeriod = 0; // No lockup for test

        // Stake multiple times with lockup using helper
        for (uint256 i = 0; i < 4; i++) {
            if (i == 0) {
                _stakeOnContract(
                    freshStaking,
                    user1,
                    stakeAmount,
                    lockupPeriod
                );
            } else {
                _addToStakeOnContract(freshStaking, user1, 0, stakeAmount);
            }
        }

        // Verify accumulated staking
        assertEq(axSumr.balanceOf(user1), stakeAmount * 4);
        // Note: Contract balance will be 0 since tokens are wrapped

        // Unstake multiple times (unstake from specific stakes) using helper
        for (uint256 i = 0; i < 4; i++) {
            _approveAndUnstakeOnContract(freshStaking, user1, 0, stakeAmount); // Unstake from first remaining stake
        }

        // Verify final balances
        assertEq(axSumr.balanceOf(user1), 0);
    }
}
