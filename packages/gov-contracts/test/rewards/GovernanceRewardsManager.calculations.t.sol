// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./GovernanceRewardsManager.general.t.sol";
import {console} from "forge-std/console.sol";
import {SummerGovernorTestBase} from "../governor/SummerGovernorTestBase.sol";

contract GovernanceRewardsManagerCalculationsTest is SummerGovernorTestBase {
    GovernanceRewardsManager public stakingRewardsManager;
    IERC20[] public rewardTokens;

    uint256 constant INITIAL_REWARD_AMOUNT = 1000000 * 1e18;
    uint256 constant INITIAL_STAKE_AMOUNT = 100000 * 1e18;

    function setUp() public override {
        super.setUp();

        // Deploy reward tokens
        for (uint i = 0; i < 3; i++) {
            rewardTokens.push(aSummerToken);
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

        // Delegate
        vm.prank(alice);
        aSummerToken.delegate(alice);
        vm.prank(bob);
        aSummerToken.delegate(bob);

        // Approve staking
        vm.prank(alice);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);
        vm.prank(bob);
        aSummerToken.approve(address(stakingRewardsManager), type(uint256).max);

        deal(
            address(rewardTokens[0]),
            address(mockGovernor),
            100000000000000000000
        ); // Mint 100 tokens
    }

    function test_RewardPerToken_NoSupply() public view {
        // When total supply is 0, should return stored value
        (, , , , uint256 storedValue) = stakingRewardsManager.rewardData(
            address(rewardTokens[0])
        );

        assertEq(
            stakingRewardsManager.rewardPerToken(address(rewardTokens[0])),
            storedValue,
            "Should return stored value when supply is 0"
        );
    }

    function test_RewardPerToken_WithSupply() public {
        uint256 stakeAmount = 1000 * 1e18;
        uint256 rewardAmount = 100 * 1e18;

        // Setup staking
        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        stakingRewardsManager.stake(stakeAmount);
        vm.stopPrank();

        // Setup reward
        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            7 days
        );
        vm.stopPrank();

        // Move forward in time
        vm.warp(block.timestamp + 1 days);

        // Calculate expected reward per token
        uint256 timePassed = 1 days;
        (
            ,
            uint256 rewardRate,
            ,
            ,
            uint256 rewardPerTokenStored
        ) = stakingRewardsManager.rewardData(address(rewardTokens[0]));

        uint256 expectedRewardPerToken = rewardPerTokenStored +
            ((timePassed * rewardRate) / stakeAmount);

        assertEq(
            stakingRewardsManager.rewardPerToken(address(rewardTokens[0])),
            expectedRewardPerToken,
            "RewardPerToken calculation mismatch"
        );
    }

    function test_GetRewardForDuration_SingleRewardToken() public {
        uint256 rewardAmount = 100 * 1e18;
        uint256 duration = 7 days;

        vm.startPrank(address(mockGovernor));
        rewardTokens[0].approve(address(stakingRewardsManager), rewardAmount);
        stakingRewardsManager.notifyRewardAmount(
            address(rewardTokens[0]),
            rewardAmount,
            duration
        );
        vm.stopPrank();

        assertApproxEqAbs(
            stakingRewardsManager.getRewardForDuration(
                address(rewardTokens[0])
            ),
            rewardAmount,
            10, // Allow difference of up to 10 wei
            "GetRewardForDuration should return approximately total reward"
        );
    }

    function test_CalculateSmoothedDecayFactor() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Initial state - should be max value (1e18) when just staked
        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        stakingRewardsManager.stake(stakeAmount); //

        assertEq(
            stakingRewardsManager.calculateSmoothedDecayFactor(alice),
            1e18,
            "Initial decay factor should be 1e18"
        );

        // Move forward in time - decay factor should decrease
        vm.warp(block.timestamp + 31 days);

        uint256 decayFactor = stakingRewardsManager
            .calculateSmoothedDecayFactor(alice);
        assertLt(decayFactor, 1e18, "Decay factor should decrease over time");
        assertGt(decayFactor, 0, "Decay factor should be greater than 0");

        vm.stopPrank();
    }

    function test_CalculateSmoothedDecayFactor_WithEMA() public {
        uint256 stakeAmount = 1000 * 1e18;

        // Setup initial state
        vm.startPrank(alice);
        aSummerToken.delegate(alice);
        stakingRewardsManager.stake(stakeAmount);

        // Initial decay factor should be 1e18
        assertEq(
            stakingRewardsManager.calculateSmoothedDecayFactor(alice),
            1e18,
            "Initial decay factor should be 1e18"
        );
        vm.stopPrank();

        // Grant decay controller role to alice
        vm.prank(address(mockGovernor));
        accessManagerA.grantDecayControllerRole(alice);

        // Move past decay free window and trigger an update
        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        stakingRewardsManager.updateSmoothedDecayFactor(alice);
        uint256 firstDecayFactor = stakingRewardsManager
            .calculateSmoothedDecayFactor(alice);

        // Move forward again and check EMA behavior
        vm.warp(block.timestamp + 31 days);
        vm.prank(alice);
        stakingRewardsManager.updateSmoothedDecayFactor(alice);
        uint256 secondDecayFactor = stakingRewardsManager
            .calculateSmoothedDecayFactor(alice);

        // The second decay factor should be less than the first due to EMA
        assertLt(
            secondDecayFactor,
            firstDecayFactor,
            "Second decay factor should be less than first due to EMA"
        );

        // Verify the decay factors are within expected bounds
        assertGt(
            firstDecayFactor,
            0,
            "First decay factor should be greater than 0"
        );
        assertLt(
            firstDecayFactor,
            1e18,
            "First decay factor should be less than 1e18"
        );
        assertGt(
            secondDecayFactor,
            0,
            "Second decay factor should be greater than 0"
        );
    }
}
