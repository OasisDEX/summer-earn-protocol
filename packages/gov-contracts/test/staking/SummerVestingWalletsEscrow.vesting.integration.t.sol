// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Origin, SummerGovernorV2} from "../../src/contracts/SummerGovernorV2.sol";
import {ISummerGovernorErrors} from "../../src/errors/ISummerGovernorErrors.sol";

import {ISummerGovernorV2} from "../../src/interfaces/ISummerGovernorV2.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import {SummerToken} from "../../src/contracts/SummerToken.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import {ISummerToken} from "../../src/interfaces/ISummerToken.sol";
import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";

import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {SummerVestingWalletsEscrowTestBase} from "../staking/SummerVestingWalletsEscrowTestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ExposedSummerTimelockController} from "../token/SummerTokenTestBase.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernorV2 functionality.
 */
contract SummerGovernorV2VestingTest is SummerVestingWalletsEscrowTestBase {
    // ========================================
    // VESTING GOVERNANCE TESTS
    // ========================================

    function test_VestingWalletVoting_UserHasVestingWallets_ReleasedTokens()
        public
    {
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper function (don't transfer ownership yet)
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "V1 Test goal"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                totalAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: USER_1_VESTING_1_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT,
                    "V2 Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power - should only include direct staking since vesting wallets aren't staked yet
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = directAmount; // Only direct staking initially

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should only include direct tokens when vesting wallets are not staked"
        );

        // Check vesting wallet balance before release for debugging

        // Check Alice balance before release
        uint256 aliceBalanceBeforeRelease = aSummerToken.balanceOf(alice);

        // fast forward past cliff for vesting wallet v2
        vm.warp(block.timestamp + CLIFF_PERIOD_DAYS + 1);

        SummerVestingWallet(vestingWalletV2).release(address(aSummerToken));
        uint256 aliceBalanceAfterRelease = aSummerToken.balanceOf(alice);
        uint256 releasedAmount = aliceBalanceAfterRelease -
            aliceBalanceBeforeRelease;

        // malicious actor send sumr to vesting wallet v2
        vm.prank(address(timelockA));
        aSummerToken.transfer(vestingWalletV2, USER_1_VESTING_1_CLIFF_AMOUNT);

        // Check that Alice received the released cliff amount
        assertEq(
            releasedAmount,
            USER_1_VESTING_1_CLIFF_AMOUNT,
            "Alice should receive the cliff amount after release"
        );

        // Check that vesting wallets still have their remaining balances
        uint256 vestingWallets1Balance = aSummerToken.balanceOf(
            vestingWalletV1
        );
        uint256 vestingWallets2Balance = aSummerToken.balanceOf(
            vestingWalletV2
        );

        // V2 should have: total - cliff + malicious transfer = 500000 + 125000 + 250000 = 875000
        // V1 should have: 500000 (unchanged)
        assertEq(
            vestingWallets1Balance,
            USER_1_VESTING_1_AMOUNT,
            "V1 vesting wallet should still have its full amount"
        );
        assertEq(
            vestingWallets2Balance,
            USER_1_VESTING_1_AMOUNT +
                USER_1_VESTING_1_CLIFF_AMOUNT +
                USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT,
            "V2 vesting wallet should have total amount + cliff + performance goals"
        );
    }

    function test_VestingWalletVoting_UserHasVestingWallets() public {
        // Setup: Create vesting wallets for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                totalAmount: vestingAmount,
                cliffAmount: USER_1_VESTING_1_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power includes vesting balances
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + // V1 wallet
            vestingAmount + // V2 total vesting
            USER_1_VESTING_1_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT + // V2 performance goal
            directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include vesting wallet balances"
        );
    }
    function test_VestingWalletVoting_UserHasOneVestingWallet() public {
        // Setup: Create only one vesting wallet for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power includes vesting balance
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include single vesting wallet balance"
        );
    }

    function test_VestingWalletVoting_UserHasNoVestingWallets() public {
        uint256 directAmount = USER_1_DIRECT_AMOUNT;
        stakeAndGetXSumr(alice, directAmount, true);

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power without vesting wallets
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when no vesting wallets"
        );
    }

    function test_VestingWalletVoting_UserHasEmptyVestingWallets() public {
        // Setup: Create empty vesting wallets for Alice
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Create empty vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: 0,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        // Note: stakeWithVesting would revert for empty wallets, but let's test the governor behavior
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power with empty vesting wallets
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when vesting wallets are empty"
        );
    }

    function test_VestingWalletVoting_MultipleCalls() public {
        // Setup: Create vesting wallets for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include vesting wallet balance"
        );

        // Second call to stakeWithVesting should not add more voting power
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_VestingWalletsEmpty()")
        );
        aStaking.stakeWithVesting();

        // Voting power should remain the same
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPowerAfter,
            expectedVotingPower,
            "Alice's voting power should remain the same after second staking call"
        );
    }

    function test_VestingWalletVoting_VestingWalletNotOwnedByStaking() public {
        // Setup: Create vesting wallet but don't transfer ownership to staking
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function but don't transfer to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        // Don't transfer ownership to staking - keep it with alice
        // Try to stake with vesting - should revert due to ownership
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        aStaking.stakeWithVesting();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power without staked vesting
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when vesting wallet not owned by staking"
        );
    }

    function test_VestingWalletVoting_MixedOwnedAndUnownedWallets() public {
        // Setup: Create two vesting wallets but only transfer ownership of one to staking
        uint256 vestingAmount1 = USER_1_VESTING_1_AMOUNT;
        uint256 vestingAmount2 = USER_1_VESTING_2_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions - only transfer first to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount1,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                totalAmount: vestingAmount2,
                cliffAmount: USER_1_VESTING_2_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        // Only transfer ownership of the first wallet to staking, leave second wallet unowned
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        // Note: vestingWalletV2 remains owned by alice, not staking

        // Try to stake with vesting - should revert due to unowned wallet
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power - should only include direct tokens (no vesting wallets staked)
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertEq(
            aliceVotingPower,
            directAmount,
            "Alice's voting power should only include direct tokens when vesting wallets are not owned by staking"
        );
    }

    function test_VestingWalletVoting_ProposalThresholdWithVesting() public {
        // Test that users with vesting wallets can meet proposal thresholds
        uint256 vestingAmount = PROPOSAL_THRESHOLD_TEST_AMOUNT; // Above minimum threshold
        uint256 directAmount = BELOW_THRESHOLD_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power meets proposal threshold
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertGe(
            aliceVotingPower,
            governorA.proposalThreshold(),
            "Alice's voting power should meet proposal threshold with vesting wallets"
        );

        // Alice should be able to create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        assertGt(
            proposalId,
            0,
            "Alice should be able to create a proposal with vesting wallet voting power"
        );
    }

    function test_VestingWalletVoting_BelowProposalThreshold() public {
        // Test that users below proposal threshold cannot create proposals even with vesting
        uint256 vestingAmount = BELOW_THRESHOLD_VESTING_AMOUNT; // Below minimum threshold
        uint256 directAmount = BELOW_THRESHOLD_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power is below proposal threshold
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );

        assertLt(
            aliceVotingPower,
            governorA.proposalThreshold(),
            "Alice's voting power should be below proposal threshold"
        );

        // Alice should NOT be able to create a proposal
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "SummerGovernorProposerBelowThresholdAndNotGuardian(address,uint256,uint256)",
                alice,
                aliceVotingPower,
                governorA.proposalThreshold()
            )
        );
        createProposal();
        vm.stopPrank();
    }

    // ========================================
    // VESTING UNSTAKING TESTS
    // ========================================

    function test_UnstakeVesting_UserHasNoVestingWallets() public {
        uint256 directAmount = USER_1_DIRECT_AMOUNT;
        stakeAndGetXSumr(alice, directAmount, true);

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Attempt to unstake vesting - should revert since no vesting wallets staked
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature("Staking_NoVestingWalletsStaked()")
        );
        aStaking.unstakeVesting();
    }

    function test_UnstakeVesting_VestingWalletNotOwnedByStaking() public {
        // Setup: Create vesting wallet for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power includes vesting
        uint256 aliceVotingPowerBefore = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;
        assertEq(aliceVotingPowerBefore, expectedVotingPower);

        // Change ownership of vesting wallet to someone else (simulating an issue)
        vm.prank(address(aStaking));
        SummerVestingWallet(vestingWalletV1).transferOwnership(bob);

        // Attempt to unstake vesting - should revert due to ownership
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        aStaking.unstakeVesting();

        // Voting power should remain the same since unstaking failed
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            aliceVotingPowerAfter,
            expectedVotingPower,
            "Voting power should remain unchanged when unstaking fails"
        );
    }

    function test_UnstakeVesting_MixedOwnedAndUnownedWallets2() public {
        // Setup: Create two vesting wallets for Alice
        uint256 vestingAmount1 = USER_1_VESTING_1_AMOUNT;
        uint256 vestingAmount2 = USER_1_VESTING_2_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions - transfer both to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount1,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                totalAmount: vestingAmount2,
                cliffAmount: USER_1_VESTING_2_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        // Transfer ownership of both wallets to staking and stake
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power includes both vesting wallets
        uint256 aliceVotingPowerBefore = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount1 + // V1 wallet
            vestingAmount2 + // V2 total vesting
            USER_1_VESTING_2_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT + // V2 performance goal
            directAmount;
        assertEq(aliceVotingPowerBefore, expectedVotingPower);

        // Change ownership of one vesting wallet to someone else (mixed ownership)
        vm.prank(address(aStaking));
        SummerVestingWallet(vestingWalletV1).transferOwnership(bob);

        // Attempt to unstake vesting - should revert due to mixed ownership
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking__InvalidOwner(string)",
                "Vesting wallet not owned by staking"
            )
        );
        aStaking.unstakeVesting();

        // Voting power should remain the same since unstaking failed
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            aliceVotingPowerAfter,
            expectedVotingPower,
            "Voting power should remain unchanged when unstaking fails due to mixed ownership"
        );
    }

    function test_UnstakeVesting_SuccessfulUnstaking() public {
        // Setup: Create vesting wallet for Alice
        uint256 vestingAmount = USER_1_VESTING_1_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallet using helper function
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check initial voting power includes vesting
        uint256 aliceVotingPowerBefore = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = vestingAmount + directAmount;
        assertEq(aliceVotingPowerBefore, expectedVotingPower);

        // Successfully unstake vesting
        vm.startPrank(alice);
        axSumr.approve(address(aStaking), expectedVotingPower);
        aStaking.unstakeVesting();
        vm.stopPrank();

        advanceTimeAndBlock();

        // Check voting power after unstaking - should only include direct tokens
        uint256 aliceVotingPowerAfter = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        assertEq(
            aliceVotingPowerAfter,
            directAmount,
            "Voting power should only include direct tokens after unstaking"
        );

        // Verify vesting wallet ownership was transferred back to Alice
        assertEq(
            SummerVestingWallet(vestingWalletV1).owner(),
            alice,
            "Vesting wallet ownership should be transferred back to Alice"
        );
    }

    function test_UnstakeVesting_ValidateVestingFactoryMapping() public {
        // Setup: Create vesting wallets for Alice using both factories
        uint256 vestingAmount1 = USER_1_VESTING_1_AMOUNT;
        uint256 vestingAmount2 = USER_1_VESTING_2_AMOUNT;
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper functions - transfer both to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: vestingAmount1,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                    0
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: true,
                totalAmount: vestingAmount2,
                cliffAmount: USER_1_VESTING_2_CLIFF_AMOUNT,
                cliffPeriodDays: CLIFF_PERIOD_DAYS,
                performanceGoals: _createPerformanceGoals(
                    USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT,
                    "Test goal"
                ),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: false
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
        );

        // Transfer ownership and stake
        vm.startPrank(alice);
        SummerVestingWallet(vestingWalletV1).transferOwnership(
            address(aStaking)
        );
        SummerVestingWallet(vestingWalletV2).transferOwnership(
            address(aStaking)
        );
        aStaking.stakeWithVesting();
        vm.stopPrank();

        // Alice delegates to herself
        vm.prank(alice);
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Verify both vesting wallets are owned by staking
        assertEq(
            SummerVestingWallet(vestingWalletV1).owner(),
            address(aStaking),
            "Vesting wallet V1 should be owned by staking after staking"
        );
        assertEq(
            SummerVestingWallet(vestingWalletV2).owner(),
            address(aStaking),
            "Vesting wallet V2 should be owned by staking after staking"
        );
        assertEq(
            aStaking.userStakedVestingFactories(alice).length,
            2,
            "Alice should have 2 staked vesting factories"
        );
        assertEq(
            aStaking.userStakedVestingFactories(alice)[1],
            address(factoryVesting),
            "Alice should have factory V1 in staked vesting factories"
        );
        assertEq(
            aStaking.userStakedVestingFactories(alice)[0],
            address(factoryVestingV2),
            "Alice should have factory V2 in staked vesting factories"
        );
        // Successfully unstake vesting
        vm.startPrank(alice);
        uint256 totalVestingAmount = vestingAmount1 + // V1 wallet
            vestingAmount2 + // V2 total vesting
            USER_1_VESTING_2_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT; // V2 performance goal
        axSumr.approve(address(aStaking), totalVestingAmount);
        aStaking.unstakeVesting();
        vm.stopPrank();
        // Verify vesting wallet ownership was transferred back to Alice
        assertEq(
            SummerVestingWallet(vestingWalletV1).owner(),
            alice,
            "Vesting wallet V1 ownership should be transferred back to Alice after unstaking"
        );
        assertEq(
            SummerVestingWallet(vestingWalletV2).owner(),
            alice,
            "Vesting wallet V2 ownership should be transferred back to Alice after unstaking"
        );

        // Verify factory mappings are still correct
        assertEq(
            factoryVesting.vestingWallets(alice),
            vestingWalletV1,
            "Factory V1 should still map Alice to vesting wallet V1"
        );
        assertEq(
            factoryVestingV2.vestingWallets(alice),
            vestingWalletV2,
            "Factory V2 should still map Alice to vesting wallet V2"
        );
        assertEq(
            factoryVesting.vestingWalletOwners(vestingWalletV1),
            alice,
            "Factory V1 should map vesting wallet V1 back to Alice"
        );
        assertEq(
            factoryVestingV2.vestingWalletOwners(vestingWalletV2),
            alice,
            "Factory V2 should map vesting wallet V2 back to Alice"
        );
        assertEq(aStaking.userStakedVestingFactories(alice).length, 0);
    }

    function test_RescueWallet() public {
        // Create a vesting wallet and transfer ownership to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "Rescue test"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: true
            })
        );

        address payable vestingWallet = payable(
            factoryVesting.vestingWallets(alice)
        );
        assertEq(
            SummerVestingWallet(vestingWallet).owner(),
            address(aStaking),
            "Precondition: staking must own vesting wallet"
        );

        // Rescue wallet to a new owner (bob) via governor
        vm.prank(address(timelockA));
        aStaking.rescueWallet(vestingWallet, bob);

        // Ownership transferred to bob
        assertEq(
            SummerVestingWallet(vestingWallet).owner(),
            bob,
            "Vesting wallet should be transferred to new owner"
        );
    }

    function test_RescueWallet_InvalidNewOwner() public {
        // Create a vesting wallet and transfer ownership to staking
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "Rescue test"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: true
            })
        );

        address payable vestingWallet = payable(
            factoryVesting.vestingWallets(alice)
        );

        // Expect revert on zero address new owner
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "New owner cannot be zero address"
            )
        );
        aStaking.rescueWallet(vestingWallet, address(0));
    }

    function test_RescueToken() public {
        // Fund staking escrow with SUMMER tokens
        uint256 amount = 1_000 ether;
        vm.prank(address(timelockA));
        aSummerToken.transfer(address(aStaking), amount);
        assertEq(
            aSummerToken.balanceOf(address(aStaking)),
            amount,
            "Precondition: staking holds tokens"
        );

        // Rescue tokens to bob via governor
        vm.prank(address(timelockA));
        aStaking.rescueToken(address(aSummerToken), bob);

        // Entire balance moved from staking to bob
        assertEq(aSummerToken.balanceOf(address(aStaking)), 0);
        assertEq(aSummerToken.balanceOf(bob), amount);
    }

    function test_RescueToken_InvalidToken() public {
        // Expect revert when token address is zero
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Invalid token address"
            )
        );
        aStaking.rescueToken(address(0), bob);
    }

    function test_RescueToken_InvalidToAddress() public {
        // Expect revert when to address is zero
        vm.prank(address(timelockA));
        vm.expectRevert(
            abi.encodeWithSignature(
                "Staking_InvalidAddress(string)",
                "Invalid to address"
            )
        );
        aStaking.rescueToken(address(aSummerToken), address(0));
    }
}
