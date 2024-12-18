// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/arks/PendleLPArk.sol";
import {Test, console} from "forge-std/Test.sol";

import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";

import "../../src/events/IArkEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";

import {ArkTestBase} from "./ArkTestBase.sol";
import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {PERCENTAGE_100, Percentage, PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract PendleLPArkTestFork is Test, IArkEvents, ArkTestBase {
    PendleLPArk public ark;

    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant MARKET = 0x19588F29f9402Bb508007FeADd415c875Ee3f19F;
    address constant NEXT_MARKET = 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
    uint256 constant MARKET_EXPIRY_BLOCK = 20379839;
    address constant SY = 0x42862F48eAdE25661558AFE0A630b132038553D0;
    address constant PT = 0xa0021EF8970104c2d008F38D92f115ad56a9B8e1;
    address constant YT = 0x1e3d13932C31d7355fCb3FEc680b0cD159dC1A07;
    address constant PENDLE = 0x808507121B80c02388fAd14726482e061B8da827;
    address constant ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;
    address constant ORACLE = 0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2;

    IERC20 public usde;
    IPMarketV3 public pendleMarket;
    IPAllActionV3 public pendleRouter;

    uint256 forkBlock = 20300752;
    uint256 forkId;

    function setUp() public {
        initializeCoreContracts();
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usde = IERC20(USDE);
        pendleMarket = IPMarketV3(MARKET);
        pendleRouter = IPAllActionV3(ROUTER);

        ArkParams memory params = ArkParams({
            name: "Pendle USDE LP Ark",
            details: "Pendle USDE LP Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: USDE,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        ark = new PendleLPArk(MARKET, ORACLE, ROUTER, params);

        // Permissioning
        vm.startPrank(governor);
        ark.setNextMarket(NEXT_MARKET);
        accessManager.grantCommanderRole(
            address(address(ark)),
            address(commander)
        );
        vm.stopPrank();

        vm.startPrank(commander);
        ark.registerFleetCommander();
        vm.stopPrank();

        vm.label(USDE, "USDE");
        vm.label(MARKET, "MARKET");
        vm.label(NEXT_MARKET, "NEXT_MARKET");
        vm.label(SY, "SY");
        vm.label(PT, "PT");
        vm.label(YT, "YT");
        vm.label(PENDLE, "PENDLE");
        vm.label(ROUTER, "ROUTER");
        vm.label(ORACLE, "ORACLE");

        vm.makePersistent(address(ark));
        vm.makePersistent(address(accessManager));
        vm.makePersistent(address(configurationManager));
        vm.makePersistent(USDE);
        vm.makePersistent(MARKET);
        vm.makePersistent(PENDLE);
        vm.makePersistent(SY);
        vm.makePersistent(PT);
    }

    function test_Board_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, USDE, amount);

        // Act
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertApproxEqRel(
            assetsAfterDeposit,
            amount,
            0.5 ether,
            "Total assets should be close to deposited amount"
        );

        // Check that the Ark has received LP tokens
        uint256 lpBalance = IERC20(MARKET).balanceOf(address(ark));
        assertTrue(lpBalance > 0, "Ark should have LP tokens");

        // Simulate some time passing
        vm.warp(block.timestamp + 30 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease over time"
        );
    }

    function test_Disembark_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));

        vm.warp(block.timestamp + 1 days);
        // Act
        uint256 initialBalance = usde.balanceOf(commander);
        uint256 amountToWithdraw = ark.totalAssets();
        ark.disembark(amountToWithdraw, bytes(""));
        vm.stopPrank();

        // Assert
        uint256 finalBalance = usde.balanceOf(commander);
        assertTrue(
            finalBalance > initialBalance,
            "Commander should have received USDE back"
        );

        uint256 arkBalance = ark.totalAssets();
        assertApproxEqAbs(
            arkBalance,
            0,
            1e18,
            "Ark should have close to zero assets"
        );
    }

    function test_Harvest_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Simulate some time passing
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1000);

        uint256 totalAssetsBefore = ark.totalAssets();

        vm.prank(raft);
        (, uint256[] memory rewardAmounts) = ark.harvest("");

        uint256 totalAssetsAfter = ark.totalAssets();

        // Assert
        assertTrue(rewardAmounts[0] > 0, "Should have harvested some rewards");
        assertEq(
            totalAssetsAfter,
            totalAssetsBefore,
            "Total assets should not change significantly"
        );
    }

    function test_DepositToExpiredMarket_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 10 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.rollFork(MARKET_EXPIRY_BLOCK);

        // Act
        vm.startPrank(commander);

        deal(USDE, commander, 10 * amount);
        usde.approve(address(ark), amount);
        vm.expectRevert(abi.encodeWithSignature("MarketExpired()"));
        ark.board(amount, bytes(""));

        vm.stopPrank();
    }

    function test_WithdrawFromExpiredMarket_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 10 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.rollFork(MARKET_EXPIRY_BLOCK);

        // Act
        vm.startPrank(commander);
        ark.disembark(ark.totalAssets(), bytes(""));
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDisembark = ark.totalAssets();
        assertApproxEqAbs(
            assetsAfterDisembark,
            0,
            1,
            "Ark should have no assets after disembark"
        );
    }

    function test_RolloverIfNeeded_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 10 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        vm.rollFork(block.number + 120000);

        // Act
        vm.startPrank(commander);

        deal(USDE, commander, 10 * amount);
        usde.approve(address(ark), amount);
        ark.board(amount, bytes(""));

        vm.stopPrank();

        // Assert
        uint256 assetsAfterRollover = ark.totalAssets();
        assertTrue(
            assetsAfterRollover > 0,
            "Ark should have assets after rollover"
        );
    }

    function test_SlippageControl_PendleLPArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 2 * amount);

        vm.startPrank(governor);
        ark.setSlippagePercentage(PercentageUtils.fromFraction(1, 1000)); // Set slippage to 0.1%

        vm.expectRevert(
            abi.encodeWithSignature(
                "SlippagePercentageTooHigh(uint256,uint256)",
                PercentageUtils.fromFraction(101, 100),
                PERCENTAGE_100
            )
        );
        ark.setSlippagePercentage(PercentageUtils.fromFraction(101, 100)); // Set slippage to 101%
        vm.stopPrank();

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        // Act & Assert
        ark.board(amount, bytes("")); // This should succeed with 0.1% slippage
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", commander)
        );
        ark.setSlippagePercentage(PercentageUtils.fromFraction(1, 10000)); // Set slippage to 0.01%
        IERC20(usde).approve(address(ark), amount);
        ark.board(amount, bytes("")); // This should fail due to tight slippage

        vm.stopPrank();
    }

    function test_OracleDurationUpdate_PendleLPArk_fork() public {
        // Arrange
        vm.startPrank(governor);

        // Act & Assert
        ark.setOracleDuration(1800); // This should succeed (30 minutes)
        vm.expectRevert(
            abi.encodeWithSignature(
                "OracleDurationTooLow(uint32,uint256)",
                10 minutes,
                15 minutes
            )
        );
        ark.setOracleDuration(600); // This should fail (10 minutes is too low)

        vm.stopPrank();
    }

    function test_RevertOnInvalidAssetForSY() public {
        address invalidAsset = address(0x123); // Some random address

        vm.mockCall(
            SY,
            abi.encodeWithSignature("isValidTokenIn(address)", invalidAsset),
            abi.encode(false)
        );
        vm.mockCall(
            SY,
            abi.encodeWithSignature("isValidTokenOut(address)", invalidAsset),
            abi.encode(false)
        );

        ArkParams memory params = ArkParams({
            name: "Invalid Asset Ark",
            details: "Invalid Asset Ark details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: invalidAsset,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_100
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidAssetForSY()"));
        new PendleLPArk(MARKET, ORACLE, ROUTER, params);
    }

    function test_RevertWhenNoValidNextMarket() public {
        // Setup: Board some assets first
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 2 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), 2 * amount);
        ark.board(amount, bytes(""));
        vm.stopPrank();

        // Fast forward time past market expiry
        vm.warp(ark.marketExpiry() + 1);

        // Mock _findNextMarket to return address(0)
        vm.mockCall(
            address(ark),
            abi.encodeWithSignature("nextMarket()"),
            abi.encode(address(0))
        );

        // Attempt to trigger rollover
        vm.expectRevert(abi.encodeWithSignature("InvalidNextMarket()"));
        vm.prank(commander);
        ark.board(amount, bytes(""));
    }
}
