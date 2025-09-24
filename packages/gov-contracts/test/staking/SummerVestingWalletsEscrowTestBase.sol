// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorV2TestBase} from "../governorV2/SummerGovernorV2TestBase.sol";
import {SummerVestingWalletsEscrow} from "../../src/contracts/SummerVestingWalletsEscrow.sol";
import {SummerVestingWalletFactoryV2} from "../../src/contracts/SummerVestingWalletFactoryV2.sol";
import {ISummerVestingWalletV2} from "../../src/interfaces/ISummerVestingWalletV2.sol";
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
    address[] public vestingFactories;
    address[] public onlyV1VestingFactory;
    address[] public onlyV2VestingFactory;

    function setUp() public virtual override {
        super.setUp();

        address[] memory emptyVestingFactories = new address[](0);
        vestingFactories = new address[](2);
        vestingFactories[0] = address(factoryVestingV2);
        vestingFactories[1] = address(factoryVesting);
        onlyV1VestingFactory = new address[](1);
        onlyV1VestingFactory[0] = address(factoryVesting);
        onlyV2VestingFactory = new address[](1);
        onlyV2VestingFactory[0] = address(factoryVestingV2);
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
    function createFreshEscrow() internal returns (SummerVestingWalletsEscrow) {
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
        uint256 vestingAmount;
        uint256 cliffAmount;
        uint256 cliffPeriodDays;
        ISummerVestingWalletV2.PerformanceGoal[] performanceGoals;
        ISummerVestingWallet.VestingType vestingType;
        bool transferToStaking;
        bool stakeVesting;
    }

    // Internal helper to create vesting wallets from config array
    function _createVestingWallets(
        VestingWalletConfig[] memory configs
    ) internal {
        for (uint256 i = 0; i < configs.length; i++) {
            VestingWalletConfig memory config = configs[i];

            // Calculate total amount needed including performance goals
            uint256 vestingAmount = config.vestingAmount;
            if (config.isV2) {
                vestingAmount += config.cliffAmount;
                for (uint256 j = 0; j < config.performanceGoals.length; j++) {
                    vestingAmount += config.performanceGoals[j].amount;
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
                        vestingAmount += config.performanceGoals[j].amount;
                    }
                }
            }

            vm.prank(address(timelockA));
            aSummerToken.transfer(foundation, vestingAmount);

            vm.startPrank(foundation);
            address vestingWallet;
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
                            totalVestingAmount: config.vestingAmount
                        });

                aSummerToken.approve(address(factoryVestingV2), vestingAmount);
                vestingWallet = factoryVestingV2.createVestingWallet(
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

                aSummerToken.approve(address(factoryVesting), vestingAmount);
                vestingWallet = factoryVesting.createVestingWallet(
                    config.user,
                    config.vestingAmount,
                    goalAmounts,
                    config.vestingType
                );
            }

            vm.stopPrank();

            // Transfer ownership to staking if requested
            if (config.transferToStaking) {
                _transferVestingWalletToStaking(
                    config.user,
                    payable(vestingWallet)
                );
            }
            if (config.stakeVesting) {
                _stakeVestingWallet(config.user, vestingWallet, config.isV2);
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
    function _transferVestingWalletToStaking(
        address user,
        address payable vestingWallet
    ) internal {
        vm.startPrank(user);
        SummerVestingWallet(vestingWallet).transferOwnership(address(aStaking));
        vm.stopPrank();
    }

    function _stakeVestingWallet(
        address user,
        address vestingWallet,
        bool isV2
    ) internal {
        vm.startPrank(user);
        address[] memory factories = new address[](1);
        factories[0] = isV2
            ? address(factoryVestingV2)
            : address(factoryVesting);
        aStaking.stakeVesting(factories);
        vm.stopPrank();
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
}
