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
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";
import {SummerTokenTestBase} from "../token/SummerTokenTestBase.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ExposedSummerGovernor, SummerGovernorV2TestBase} from "./SummerGovernorV2TestBase.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ExposedSummerTimelockController} from "../token/SummerTokenTestBase.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {SummerVestingWalletFactory} from "../../src/contracts/SummerVestingWalletFactory.sol";

import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";

/*
 * @title SummerGovernorTest
 * @dev Test contract for SummerGovernorV2 functionality.
 */
contract SummerGovernorTest is SummerGovernorV2TestBase {
    function test_VotingPowerIncludesVestingWalletBalance() public {
        // Setup: Create two vesting wallets for Alice
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;

        // Setup parameters
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: vestingAmount / 4,
                vestingPeriods: 12,
                totalVestingAmount: vestingAmount
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                1
            );
        performanceGoals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: vestingAmount / 2,
            description: "Test goal",
            reached: false
        });
        uint256 totalAmountV1 = vestingAmount;
        uint256 totalAmountV2 = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount +
            performanceGoals[0].amount;

        unstakeTokens(whale, totalAmountV2 + totalAmountV1, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, totalAmountV2 + totalAmountV1);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVestingV2), totalAmountV2);
        aSummerToken.approve(address(factoryVesting), totalAmountV1);
        factoryVestingV2.createVestingWallet(
            alice,
            vestingParams,
            performanceGoals
        );
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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

        // Check Alice's voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = totalAmountV1 +
            totalAmountV2 +
            directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include both locked and unlocked tokens"
        );

        // Create a proposal
        vm.prank(alice);
        (uint256 proposalId, ) = createProposal();

        advanceTimeForVotingDelay();

        // Alice votes
        vm.prank(alice);
        governorA.castVote(proposalId, 1);

        // Check proposal votes
        (, uint256 forVotes, ) = governorA.proposalVotes(proposalId);

        assertEq(
            forVotes,
            expectedVotingPower,
            "Proposal votes should reflect Alice's full voting power"
        );
    }

    // ========================================
    // VESTING GOVERNANCE TESTS
    // ========================================

    function test_VestingWalletVoting_UserHasVestingWallets() public {
        // Setup: Create vesting wallets for Alice
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;

        // Setup parameters
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: vestingAmount / 4,
                vestingPeriods: 12,
                totalVestingAmount: vestingAmount
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                1
            );
        performanceGoals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: vestingAmount / 2,
            description: "Test goal",
            reached: false
        });
        uint256 totalAmountV1 = vestingAmount;
        uint256 totalAmountV2 = vestingParams.cliffAmount +
            vestingParams.totalVestingAmount +
            performanceGoals[0].amount;

        unstakeTokens(whale, totalAmountV2 + totalAmountV1, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, totalAmountV2 + totalAmountV1);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVestingV2), totalAmountV2);
        aSummerToken.approve(address(factoryVesting), totalAmountV1);
        factoryVestingV2.createVestingWallet(
            alice,
            vestingParams,
            performanceGoals
        );
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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
        uint256 expectedVotingPower = totalAmountV1 +
            totalAmountV2 +
            directAmount;

        assertEq(
            aliceVotingPower,
            expectedVotingPower,
            "Alice's voting power should include vesting wallet balances"
        );
    }

    function test_VestingWalletVoting_UserHasOneVestingWallet() public {
        // Setup: Create only one vesting wallet for Alice
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;

        unstakeTokens(whale, vestingAmount, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, vestingAmount);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVesting), vestingAmount);
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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
        uint256 directAmount = 1000000 * 10 ** 18;
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
        uint256 directAmount = 1000000 * 10 ** 18;

        // Create vesting wallets but don't fund them
        vm.startPrank(foundation);
        factoryVesting.createVestingWallet(
            alice,
            0,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;

        unstakeTokens(whale, vestingAmount, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, vestingAmount);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVesting), vestingAmount);
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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
        uint256 vestingAmount = 500000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;

        unstakeTokens(whale, vestingAmount, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, vestingAmount);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVesting), vestingAmount);
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );

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
        uint256 vestingAmount1 = 500000 * 10 ** 18;
        uint256 vestingAmount2 = 300000 * 10 ** 18;
        uint256 directAmount = 1000000 * 10 ** 18;
        uint256 totalVestingAmount1 = vestingAmount1;
        uint256 totalVestingAmount2 = vestingAmount2 +
            vestingAmount2 /
            4 +
            vestingAmount2 /
            2;
        uint256 totalVestingAmount = totalVestingAmount1 + totalVestingAmount2;

        unstakeTokens(whale, totalVestingAmount, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, totalVestingAmount);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVesting), totalVestingAmount1);
        aSummerToken.approve(address(factoryVestingV2), totalVestingAmount2);

        // Create first vesting wallet (V1)
        factoryVesting.createVestingWallet(
            alice,
            totalVestingAmount1,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );

        // Create second vesting wallet (V2)
        ISummerVestingWalletV2.VestingParams
            memory vestingParams = ISummerVestingWalletV2.VestingParams({
                cliffEndTimestamp: uint64(block.timestamp + 180 days),
                cliffAmount: vestingAmount2 / 4,
                vestingPeriods: 12,
                totalVestingAmount: vestingAmount2
            });

        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                1
            );
        performanceGoals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: vestingAmount2 / 2,
            description: "Test goal",
            reached: false
        });

        factoryVestingV2.createVestingWallet(
            alice,
            vestingParams,
            performanceGoals
        );
        vm.stopPrank();

        stakeAndGetXSumr(alice, directAmount, true);

        address payable vestingWalletV1 = payable(
            factoryVesting.vestingWallets(alice)
        );
        address payable vestingWalletV2 = payable(
            factoryVestingV2.vestingWallets(alice)
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
        uint256 vestingAmount = 2000000 * 10 ** 18; // Above minimum threshold
        uint256 directAmount = 100000 * 10 ** 18;

        unstakeTokens(whale, vestingAmount, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, vestingAmount);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVesting), vestingAmount);
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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
        uint256 vestingAmount = 500 * 10 ** 18; // Below minimum threshold
        uint256 directAmount = 100 * 10 ** 18;

        unstakeTokens(whale, vestingAmount, true);
        vm.prank(whale);
        aSummerToken.transfer(foundation, vestingAmount);

        vm.startPrank(foundation);
        aSummerToken.approve(address(factoryVesting), vestingAmount);
        factoryVesting.createVestingWallet(
            alice,
            vestingAmount,
            new uint256[](0),
            ISummerVestingWallet.VestingType.TeamVesting
        );
        vm.stopPrank();
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
}
