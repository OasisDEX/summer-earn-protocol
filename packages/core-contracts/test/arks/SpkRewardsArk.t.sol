// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/SkyRewardsArk.sol";
import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {IStakingRewards} from "../../src/interfaces/sky/IStakingRewards.sol";
import {ILitePSM} from "../../src/interfaces/sky/ILitePSM.sol";
import {PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {Test, console} from "forge-std/Test.sol";

contract SpkRewardsArkTestFork is Test, IArkEvents, ArkTestBase {
    SkyRewardsArk public ark;

    // Known contract addresses - SPK rewards (mainnet)
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant SPK_STAKING =
        0x173e314C7635B45322cd8Cb14f44b312e079F3af;
    address public constant SPK_TOKEN =
        0xc20059e0317DE91738d13af027DfC4a50781b066;
    address public constant LITE_PSM =
        0xA188EEC8F81263234dA3622A406892F3D630f98c;

    IERC20 public usdc;
    IERC20 public usds;
    IStakingRewards public stakingRewards;
    ILitePSM public litePsm;

    uint256 forkBlock = 24416332;
    uint256 futureBlock = 24426332;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usdc = IERC20(USDC);
        usds = IERC20(USDS);
        stakingRewards = IStakingRewards(SPK_STAKING);
        litePsm = ILitePSM(LITE_PSM);

        ArkParams memory params = ArkParams({
            name: "SpkRewardsArk",
            details: "USDC to stakedUSDS with SPK rewards Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDC,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new SkyRewardsArk(LITE_PSM, USDS, SPK_STAKING, params);

        // Permissioning
        vm.startPrank(governor);
        accessManager.grantCommanderRole(address(ark), address(commander));
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        vm.label(address(ark), "SpkRewardsArk");
        vm.label(address(usdc), "USDC");
        vm.label(address(usds), "USDS");
        vm.label(address(stakingRewards), "SPK_STAKING");
        vm.label(address(litePsm), "LITE_PSM");
        vm.label(address(accessManager), "accessManager");
        vm.label(address(configurationManager), "configurationManager");
        vm.label(SPK_TOKEN, "SPK_TOKEN");

        vm.makePersistent(address(ark));
        vm.makePersistent(USDC);
        vm.makePersistent(USDS);
        vm.makePersistent(SPK_STAKING);
        vm.makePersistent(LITE_PSM);
        vm.makePersistent(address(accessManager));
        vm.makePersistent(address(configurationManager));
    }

    function test_Board_SpkRewardsArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 6; // USDC has 6 decimals
        deal(address(usdc), commander, amount);

        vm.startPrank(commander);
        usdc.approve(address(ark), amount);

        // Expect the Boarded event
        vm.expectEmit();
        emit Boarded(commander, address(usdc), amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        assertGt(ark.totalAssets(), 0, "Should have assets after boarding");

        // Check yield accrual (principal only, rewards accrue separately)
        uint256 assetsAfterDeposit = ark.totalAssets();
        vm.warp(block.timestamp + 10000);
        uint256 assetsAfterAccrual = ark.totalAssets();
        assertEq(
            assetsAfterAccrual,
            assetsAfterDeposit,
            "Should not accrue yield over time (principal stable)"
        );
    }

    function test_Disembark_SpkRewardsArk_fork() public {
        // First board some assets so we have something to disembark
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));

        // Wait some time to accrue rewards
        vm.warp(block.timestamp + 1000);

        // Get current balance before disembark
        uint256 commanderUsdcBefore = usdc.balanceOf(commander);
        uint256 arkTotalBefore = ark.totalAssets();

        // Calculate amount to disembark (half of total)
        uint256 disembarkAmount = arkTotalBefore / 2;
        // Expect the Disembarked event
        vm.expectEmit();
        emit Disembarked(commander, address(usdc), disembarkAmount);

        // Act
        ark.disembark(disembarkAmount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 commanderUsdcAfter = usdc.balanceOf(commander);
        uint256 arkTotalAfter = ark.totalAssets();

        assertEq(
            arkTotalAfter,
            arkTotalBefore - disembarkAmount,
            "Ark total assets should decrease by disembark amount"
        );
        assertGt(
            commanderUsdcAfter,
            commanderUsdcBefore,
            "Commander should receive USDC"
        );
    }

    function test_Harvest_SpkRewardsArk_fork() public {
        // First board some assets to generate rewards
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));
        vm.stopPrank();

        // Wait some time to accrue SPK rewards
        vm.warp(block.timestamp + 10000);

        // Get rewards token balance before harvest
        IERC20 rewardsToken = ark.rewardsToken();
        assertEq(
            address(rewardsToken),
            SPK_TOKEN,
            "Rewards token should be SPK"
        );
        uint256 rewardsBeforeRaft = rewardsToken.balanceOf(address(raft));

        // Harvest rewards
        vm.startPrank(raft);
        (address[] memory rewardTokens, uint256[] memory rewardAmounts) = ark
            .harvest(bytes(""));
        vm.stopPrank();

        // Assert
        uint256 rewardsAfterRaft = rewardsToken.balanceOf(address(raft));
        assertEq(
            rewardTokens[0],
            address(rewardsToken),
            "Should have harvested SPK rewards"
        );
        assertEq(
            rewardsAfterRaft - rewardsBeforeRaft,
            rewardAmounts[0],
            "Should have transferred SPK rewards to raft"
        );
        assertGt(rewardAmounts[0], 0, "Should have accrued rewards");
    }

    function test_Disembark_AfterYieldAccrual_CheckLeftovers() public {
        // Arrange - Initial deposit
        uint256 boardAmount = 1000 * 10 ** 6; // 1000 USDC
        deal(address(usdc), commander, boardAmount);

        vm.startPrank(commander);
        usdc.approve(address(ark), boardAmount);
        ark.board(boardAmount, bytes(""));
        vm.stopPrank();

        // Simulate yield accrual by moving to future block
        vm.rollFork(futureBlock);

        // Record balances before withdrawal
        uint256 totalAssetsBeforeWithdraw = ark.totalAssets();
        uint256 commanderUsdcBefore = usdc.balanceOf(commander);

        // Withdraw all assets
        vm.startPrank(commander);
        ark.disembark(totalAssetsBeforeWithdraw, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 arkUsdcBalance = usdc.balanceOf(address(ark));
        uint256 arkTotalAssets = ark.totalAssets();
        uint256 commanderUsdcAfter = usdc.balanceOf(commander);

        // Check that commander received deposited amount (principal only, no yield on principal)
        assertEq(
            commanderUsdcAfter - commanderUsdcBefore,
            boardAmount,
            "Should receive same amount as deposited (principal)"
        );

        // Check for any leftover balances
        assertEq(
            arkUsdcBalance,
            0,
            "Ark should have no USDC balance after full withdrawal"
        );
        assertEq(
            arkTotalAssets,
            0,
            "Ark should report 0 total assets after full withdrawal"
        );
    }
}
