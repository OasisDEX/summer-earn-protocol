// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";
import {GovernanceRewardsManager} from "../../src/contracts/GovernanceRewardsManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

contract GovernanceRewardsManagerTest is SummerGovernorTestBase {
    GovernanceRewardsManager public stakingRewardsManager;
    ERC20Mock[] public rewardTokens;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public override {
        super.setUp();

        // Deploy reward tokens
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(new ERC20Mock());
        }

        // Deploy GovernanceRewardsManager with aSummerToken
        stakingRewardsManager = new GovernanceRewardsManager(
            address(aSummerToken),
            address(accessManagerA)
        );

        // Grant roles
        vm.startPrank(address(timelockA));
        accessManagerA.grantDecayControllerRole(address(stakingRewardsManager));
        accessManagerA.grantGovernorRole(address(mockGovernor));
        vm.stopPrank();

        // Mint initial tokens
        vm.startPrank(address(timelockA));
        aSummerToken.transfer(alice, INITIAL_STAKE_AMOUNT);
        aSummerToken.transfer(bob, INITIAL_STAKE_AMOUNT);
        vm.stopPrank();

        // Mint reward tokens
        for (uint i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].mint(
                address(stakingRewardsManager),
                INITIAL_REWARD_AMOUNT
            );
        }

        // Approve staking
        vm.prank(alice);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);
        vm.prank(bob);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);
    }

    function test_UpdateSmoothedDecayFactor() public {
        // Grant DECAY_CONTROLLER_ROLE to the owner
        vm.prank(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(address(this));

        // Setup test
        vm.prank(alice);
        aSummerToken.delegate(alice);

        // Get initial decay factor from token
        uint256 initialDecayFactor = aSummerToken.getDecayFactor(alice);

        // First update - should equal the current decay factor since no previous value
        stakingRewardsManager.updateSmoothedDecayFactor(alice);
        assertEq(
            stakingRewardsManager.userSmoothedDecayFactor(alice),
            initialDecayFactor,
            "Initial smoothed decay factor should equal current decay factor"
        );

        // Simulate a change in decay factor
        uint256 newDecayFactor = initialDecayFactor / 2; // 50% decay
        vm.mockCall(
            address(aSummerToken),
            abi.encodeWithSelector(aSummerToken.getDecayFactor.selector, alice),
            abi.encode(newDecayFactor)
        );

        // Update again - should use EMA formula
        stakingRewardsManager.updateSmoothedDecayFactor(alice);

        // Calculate expected EMA: α * currentValue + (1 - α) * previousValue
        uint256 SMOOTHING_FACTOR = stakingRewardsManager
            .DECAY_SMOOTHING_FACTOR();
        uint256 SMOOTHING_BASE = stakingRewardsManager
            .DECAY_SMOOTHING_FACTOR_BASE();
        uint256 expectedSmoothedFactor = ((newDecayFactor * SMOOTHING_FACTOR) +
            (initialDecayFactor * (SMOOTHING_BASE - SMOOTHING_FACTOR))) /
            SMOOTHING_BASE;

        assertEq(
            stakingRewardsManager.userSmoothedDecayFactor(alice),
            expectedSmoothedFactor,
            "Smoothed decay factor should follow EMA formula"
        );

        // Clean up mock
        vm.clearMockedCalls();
    }

    function test_ZeroInitialSmoothedDecayFactor() public {
        vm.prank(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(address(this));

        uint256 currentDecayFactor = 1e18; // 100%
        vm.mockCall(
            address(aSummerToken),
            abi.encodeWithSelector(aSummerToken.getDecayFactor.selector, bob),
            abi.encode(currentDecayFactor)
        );

        // Should return current decay factor when no previous value exists
        stakingRewardsManager.updateSmoothedDecayFactor(bob);
        assertEq(
            stakingRewardsManager.userSmoothedDecayFactor(bob),
            currentDecayFactor,
            "Should return current decay factor when no previous value"
        );

        vm.clearMockedCalls();
    }

    function test_MultipleDecayUpdates() public {
        vm.prank(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(address(this));

        uint256[] memory decayFactors = new uint256[](4);
        decayFactors[0] = 1e18; // 100%
        decayFactors[1] = 0.8e18; // 80%
        decayFactors[2] = 0.5e18; // 50%
        decayFactors[3] = 0.3e18; // 30%

        // Set and update initial decay factor
        vm.mockCall(
            address(aSummerToken),
            abi.encodeWithSelector(aSummerToken.getDecayFactor.selector, alice),
            abi.encode(decayFactors[0])
        );

        stakingRewardsManager.updateSmoothedDecayFactor(alice);
        uint256 expectedSmoothed = decayFactors[0];

        assertEq(
            stakingRewardsManager.userSmoothedDecayFactor(alice),
            expectedSmoothed,
            "Initial smoothed value should equal first decay factor"
        );

        // Test subsequent updates
        for (uint i = 1; i < decayFactors.length; i++) {
            vm.mockCall(
                address(aSummerToken),
                abi.encodeWithSelector(
                    aSummerToken.getDecayFactor.selector,
                    alice
                ),
                abi.encode(decayFactors[i])
            );

            stakingRewardsManager.updateSmoothedDecayFactor(alice);

            // Calculate expected EMA
            uint256 SMOOTHING_FACTOR = stakingRewardsManager
                .DECAY_SMOOTHING_FACTOR();
            uint256 SMOOTHING_BASE = stakingRewardsManager
                .DECAY_SMOOTHING_FACTOR_BASE();
            expectedSmoothed =
                ((decayFactors[i] * SMOOTHING_FACTOR) +
                    (expectedSmoothed * (SMOOTHING_BASE - SMOOTHING_FACTOR))) /
                SMOOTHING_BASE;

            assertEq(
                stakingRewardsManager.userSmoothedDecayFactor(alice),
                expectedSmoothed,
                "Incorrect smoothed value after multiple updates"
            );
        }

        vm.clearMockedCalls();
    }

    function test_EdgeCaseDecayFactors() public {
        vm.prank(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(address(this));

        // Test with very small decay factor
        uint256 smallDecayFactor = 1;
        vm.mockCall(
            address(aSummerToken),
            abi.encodeWithSelector(aSummerToken.getDecayFactor.selector, alice),
            abi.encode(smallDecayFactor)
        );

        stakingRewardsManager.updateSmoothedDecayFactor(alice);
        assertEq(
            stakingRewardsManager.userSmoothedDecayFactor(alice),
            smallDecayFactor,
            "Should handle very small decay factors"
        );

        // Test with very large decay factor
        uint256 largeDecayFactor = 100 * Constants.WAD;

        vm.mockCall(
            address(aSummerToken),
            abi.encodeWithSelector(aSummerToken.getDecayFactor.selector, alice),
            abi.encode(largeDecayFactor)
        );

        stakingRewardsManager.updateSmoothedDecayFactor(alice);

        uint256 SMOOTHING_FACTOR = stakingRewardsManager
            .DECAY_SMOOTHING_FACTOR();
        uint256 SMOOTHING_BASE = stakingRewardsManager
            .DECAY_SMOOTHING_FACTOR_BASE();
        uint256 expectedSmoothed = ((largeDecayFactor * SMOOTHING_FACTOR) +
            (smallDecayFactor * (SMOOTHING_BASE - SMOOTHING_FACTOR))) /
            SMOOTHING_BASE;

        assertEq(
            stakingRewardsManager.userSmoothedDecayFactor(alice),
            expectedSmoothed,
            "Should handle large decay factors"
        );

        vm.clearMockedCalls();
    }
}
