// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {SummerVestingWalletsEscrow} from "../../src/contracts/SummerVestingWalletsEscrow.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
import {SummerVestingWalletsEscrow} from "../../src/contracts/SummerVestingWalletsEscrow.sol";
import {SummerVestingWallet} from "../../src/contracts/SummerVestingWallet.sol";
import {ISummerVestingWallet} from "../../src/interfaces/ISummerVestingWallet.sol";

contract SummerVestingWalletsEscrowTestBase is SummerGovernorV2TestBase {
    // unit tests constants
    uint256 public constant VESTING_AMOUNT_WALLET_1 = 1000 ether;
    uint256 public constant VESTING_AMOUNT_WALLET_2 = 500 ether;

    // integration tests constants
    uint256 constant USER_1_VESTING_1_AMOUNT = 500000 ether;
    uint256 constant USER_1_VESTING_2_AMOUNT = 300000 ether;
    uint256 constant USER_1_DIRECT_AMOUNT = 1000000 ether;
    uint256 constant PROPOSAL_THRESHOLD_TEST_AMOUNT = 2000000 ether;
    uint256 constant BELOW_THRESHOLD_VESTING_AMOUNT = 500 ether;
    uint256 constant BELOW_THRESHOLD_DIRECT_AMOUNT = 100 ether;
    uint256 constant CLIFF_PERIOD_DAYS = 180 days;
    uint256 constant VESTING_PERIODS = 12;

    // Derived constants for cleaner test code
    uint256 constant USER_1_VESTING_1_CLIFF_AMOUNT =
        USER_1_VESTING_1_AMOUNT / 4;
    uint256 constant USER_1_VESTING_2_CLIFF_AMOUNT =
        USER_1_VESTING_2_AMOUNT / 4;
    uint256 constant USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT =
        USER_1_VESTING_1_AMOUNT / 2;
    uint256 constant USER_1_VESTING_2_PERFORMANCE_GOAL_AMOUNT =
        USER_1_VESTING_2_AMOUNT / 2;

    SummerVestingWalletsEscrow public aStaking;
    SummerVestingWalletsEscrow public bStaking;

    function setUp() public virtual override {
        super.setUp();

        address[] memory emptyVestingFactories = new address[](0);
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        aStaking = new SummerVestingWalletsEscrow(
            address(accessManagerA),
            address(aSummerToken),
            address(axSumr),
            vestingFactories
        );
        bStaking = new SummerVestingWalletsEscrow(
            address(accessManagerB),
            address(bSummerToken),
            address(bxSumr),
            emptyVestingFactories
        );
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(aStaking));
        vm.prank(address(timelockB));
        bxSumr.addStakingModule(address(bStaking));
    }
    // Helper function to create a fresh staking contract for isolated tests
    function createFreshStaking()
        internal
        returns (SummerVestingWalletsEscrow)
    {
        address[] memory vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);

        SummerVestingWalletsEscrow freshStaking = new SummerVestingWalletsEscrow(
                address(accessManagerA),
                address(aSummerToken),
                address(axSumr),
                vestingFactories
            );

        // Set staking module so freshStaking can mint/burn StakedSummerToken
        vm.prank(address(timelockA));
        axSumr.addStakingModule(address(freshStaking));

        return freshStaking;
    }

    // Struct for vesting wallet configuration
    struct VestingWalletConfig {
        address user;
        bool isV2;
        uint256 totalAmount;
        uint256 cliffAmount;
        uint256 cliffPeriodDays;
        ISummerVestingWalletV2.PerformanceGoal[] performanceGoals;
        ISummerVestingWallet.VestingType vestingType;
        bool transferToStaking;
    }

    // Internal helper to create vesting wallets from config array
    function _createVestingWallets(
        VestingWalletConfig[] memory configs
    ) internal {
        for (uint256 i = 0; i < configs.length; i++) {
            VestingWalletConfig memory config = configs[i];

            // Calculate total amount needed including performance goals
            uint256 totalAmount = config.totalAmount;
            if (config.isV2) {
                totalAmount += config.cliffAmount;
                for (uint256 j = 0; j < config.performanceGoals.length; j++) {
                    totalAmount += config.performanceGoals[j].amount;
                }
            } else {
                // For V1, add performance goals to total amount if it's TeamVesting
                if (
                    config.vestingType ==
                    ISummerVestingWallet.VestingType.TeamVesting
                ) {
                    for (
                        uint256 j = 0;
                        j < config.performanceGoals.length;
                        j++
                    ) {
                        totalAmount += config.performanceGoals[j].amount;
                    }
                }
            }

            vm.prank(address(timelockA));
            aSummerToken.transfer(foundation, totalAmount);

            vm.startPrank(foundation);

            if (config.isV2) {
                // Create V2 vesting wallet with performance goals
                ISummerVestingWalletV2.VestingParams
                    memory vestingParams = ISummerVestingWalletV2
                        .VestingParams({
                            cliffEndTimestamp: uint64(
                                block.timestamp + config.cliffPeriodDays
                            ),
                            cliffAmount: config.cliffAmount,
                            vestingPeriods: VESTING_PERIODS,
                            totalVestingAmount: config.totalAmount
                        });

                aSummerToken.approve(address(factoryVestingV2), totalAmount);
                factoryVestingV2.createVestingWallet(
                    config.user,
                    vestingParams,
                    config.performanceGoals
                );
            } else {
                // Create V1 vesting wallet
                uint256[] memory goalAmounts = new uint256[](
                    config.performanceGoals.length
                );
                for (uint256 j = 0; j < config.performanceGoals.length; j++) {
                    goalAmounts[j] = config.performanceGoals[j].amount;
                }

                aSummerToken.approve(address(factoryVesting), totalAmount);
                factoryVesting.createVestingWallet(
                    config.user,
                    config.totalAmount,
                    goalAmounts,
                    config.vestingType
                );
            }

            vm.stopPrank();

            // Transfer ownership to staking if requested
            if (config.transferToStaking) {
                _transferVestingWalletToStaking(config.user, config.isV2);
            }
        }
    }

    // Helper method to create vesting wallets for a single user
    function _createVestingWalletForUser(
        VestingWalletConfig memory config
    ) internal {
        VestingWalletConfig[] memory configs = new VestingWalletConfig[](1);
        configs[0] = config;
        _createVestingWallets(configs);
    }

    // Helper to transfer vesting wallet ownership to staking
    function _transferVestingWalletToStaking(address user, bool isV2) internal {
        address payable vestingWallet = isV2
            ? payable(factoryVestingV2.vestingWallets(user))
            : payable(factoryVesting.vestingWallets(user));

        vm.startPrank(user);
        SummerVestingWallet(vestingWallet).transferOwnership(address(aStaking));
        aStaking.stakeWithVesting();
        vm.stopPrank();
    }

    // Helper functions for common vesting wallet configurations
    function _createStandardVestingConfig(
        address user,
        bool isV2,
        uint256 amount,
        bool transferToStaking
    ) internal pure returns (VestingWalletConfig memory) {
        return
            _createStandardVestingConfigWithGoals(
                user,
                isV2,
                amount,
                transferToStaking,
                amount / 2, // Default performance goal amount
                "Test goal" // Default description
            );
    }

    function _createStandardVestingConfigWithGoals(
        address user,
        bool isV2,
        uint256 amount,
        bool transferToStaking,
        uint256 performanceGoalAmount,
        string memory goalDescription
    ) internal pure returns (VestingWalletConfig memory) {
        ISummerVestingWalletV2.PerformanceGoal[]
            memory performanceGoals = new ISummerVestingWalletV2.PerformanceGoal[](
                1
            );
        performanceGoals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: performanceGoalAmount,
            description: goalDescription,
            reached: false
        });

        if (isV2) {
            return
                VestingWalletConfig({
                    user: user,
                    isV2: true,
                    totalAmount: amount,
                    cliffAmount: amount / 4,
                    cliffPeriodDays: CLIFF_PERIOD_DAYS,
                    performanceGoals: performanceGoals,
                    vestingType: ISummerVestingWallet.VestingType.TeamVesting, // Not used for V2
                    transferToStaking: transferToStaking
                });
        } else {
            return
                VestingWalletConfig({
                    user: user,
                    isV2: false,
                    totalAmount: amount,
                    cliffAmount: 0,
                    cliffPeriodDays: 0,
                    performanceGoals: performanceGoals,
                    vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                    transferToStaking: transferToStaking
                });
        }
    }

    function _createVestingConfigWithoutGoals(
        address user,
        bool isV2,
        uint256 amount,
        bool transferToStaking
    ) internal pure returns (VestingWalletConfig memory) {
        if (isV2) {
            return
                VestingWalletConfig({
                    user: user,
                    isV2: true,
                    totalAmount: amount,
                    cliffAmount: amount / 4,
                    cliffPeriodDays: CLIFF_PERIOD_DAYS,
                    performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                        0
                    ),
                    vestingType: ISummerVestingWallet.VestingType.TeamVesting, // Not used for V2
                    transferToStaking: transferToStaking
                });
        } else {
            return
                VestingWalletConfig({
                    user: user,
                    isV2: false,
                    totalAmount: amount,
                    cliffAmount: 0,
                    cliffPeriodDays: 0,
                    performanceGoals: new ISummerVestingWalletV2.PerformanceGoal[](
                        0
                    ),
                    vestingType: ISummerVestingWallet
                        .VestingType
                        .InvestorExTeamVesting,
                    transferToStaking: transferToStaking
                });
        }
    }

    // Helper to create performance goals array
    function _createPerformanceGoals(
        uint256 amount,
        string memory description
    ) internal pure returns (ISummerVestingWalletV2.PerformanceGoal[] memory) {
        ISummerVestingWalletV2.PerformanceGoal[]
            memory goals = new ISummerVestingWalletV2.PerformanceGoal[](1);
        goals[0] = ISummerVestingWalletV2.PerformanceGoal({
            amount: amount,
            description: description,
            reached: false
        });
        return goals;
    }

    // Helper to create multiple performance goals
    function _createMultiplePerformanceGoals(
        uint256[] memory amounts,
        string[] memory descriptions
    ) internal pure returns (ISummerVestingWalletV2.PerformanceGoal[] memory) {
        require(
            amounts.length == descriptions.length,
            "Amounts and descriptions length mismatch"
        );
        ISummerVestingWalletV2.PerformanceGoal[]
            memory goals = new ISummerVestingWalletV2.PerformanceGoal[](
                amounts.length
            );
        for (uint256 i = 0; i < amounts.length; i++) {
            goals[i] = ISummerVestingWalletV2.PerformanceGoal({
                amount: amounts[i],
                description: descriptions[i],
                reached: false
            });
        }
        return goals;
    }

    function test_VotingPowerIncludesVestingWalletBalance() public {
        uint256 directAmount = USER_1_DIRECT_AMOUNT;

        // Setup vesting wallets using helper function - create both V1 and V2 for Alice
        _createVestingWalletForUser(
            VestingWalletConfig({
                user: alice,
                isV2: false,
                totalAmount: USER_1_VESTING_1_AMOUNT,
                cliffAmount: 0,
                cliffPeriodDays: 0,
                performanceGoals: _createPerformanceGoals(0, "V1 Test goal"),
                vestingType: ISummerVestingWallet.VestingType.TeamVesting,
                transferToStaking: true
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
                transferToStaking: true
            })
        );

        stakeAndGetXSumr(alice, directAmount, true);

        // Alice delegates to herself
        vm.prank(alice);
        // aStaking.stakeWithVesting();
        axSumr.delegate(alice);

        advanceTimeAndBlock();

        // Check Alice's voting power
        uint256 aliceVotingPower = governorA.getVotes(
            alice,
            block.timestamp - 1
        );
        uint256 expectedVotingPower = USER_1_VESTING_1_AMOUNT + // V1 wallet
            USER_1_VESTING_1_AMOUNT + // V2 total vesting
            USER_1_VESTING_1_CLIFF_AMOUNT + // V2 cliff
            USER_1_VESTING_1_PERFORMANCE_GOAL_AMOUNT + // V2 performance goal
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
