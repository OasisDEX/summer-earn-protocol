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
}
