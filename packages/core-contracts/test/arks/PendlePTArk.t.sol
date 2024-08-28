// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/contracts/arks/PendlePTArk.sol";

import "../../src/events/IArkEvents.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../../src/interfaces/IProtocolAccessManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";

contract PendlePTArkTestFork is Test, IArkEvents {
    PendlePTArk public ark;
    address public governor = address(1);
    address public raft = address(2);
    address public tipJar = address(3);
    address public commander = address(4);

    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant MARKET = 0x19588F29f9402Bb508007FeADd415c875Ee3f19F;
    address constant NEXT_MARKET = 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
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
        forkId = vm.createSelectFork(vm.rpcUrl("mainnet"), forkBlock);

        usde = IERC20(USDE);
        pendleMarket = IPMarketV3(MARKET);
        pendleRouter = IPAllActionV3(ROUTER);

        IProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );

        IConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: address(accessManager),
                tipJar: tipJar,
                raft: raft
            })
        );

        ArkParams memory params = ArkParams({
            name: "Pendle USDE PT Ark",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            token: USDE,
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max
        });

        ark = new PendlePTArk(USDE, MARKET, ORACLE, params);

        // Permissioning
        vm.startPrank(governor);
        ark.grantCommanderRole(commander);
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
        vm.makePersistent(SY);
        vm.makePersistent(PT);
    }

    function test_Board_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);

        // Expect the Boarded event to be emitted
        vm.expectEmit();
        emit Boarded(commander, USDE, amount);

        // Act
        ark.board(amount);
        vm.stopPrank();

        // Assert
        uint256 assetsAfterDeposit = ark.totalAssets();
        assertApproxEqRel(
            assetsAfterDeposit,
            amount,
            0.5 ether,
            "Total assets should equal deposited amount"
        );

        // Check that the Ark has received PT tokens
        uint256 ptBalance = IERC20(PT).balanceOf(address(ark));
        assertTrue(ptBalance > 0, "Ark should have PT tokens");

        // Simulate some time passing
        vm.warp(block.timestamp + 30 days);

        uint256 assetsAfterAccrual = ark.totalAssets();
        assertTrue(
            assetsAfterAccrual >= assetsAfterDeposit,
            "Assets should not decrease over time"
        );
    }

    function test_Disembark_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount);

        vm.warp(block.timestamp + 1 days);
        // Act
        uint256 initialBalance = usde.balanceOf(commander);
        uint256 amountToWithdraw = ark.totalAssets();
        ark.disembark(amountToWithdraw + 1);
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

    function test_Rate_PendlePTArk_fork() public view {
        uint256 rate = ark.rate();
        assertTrue(rate > 0, "Rate should be greater than zero");

        // The rate should be fixed, so calling it again should return the same value
        assertEq(ark.rate(), rate, "Rate should remain constant");
    }

    function test_RolloverIfNeeded_PendlePTArk_fork() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 10 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount);
        vm.stopPrank();

        vm.rollFork(block.number + 120000);

        // Act
        vm.startPrank(commander);

        deal(USDE, commander, 10 * amount);
        usde.approve(address(ark), amount);
        ark.board(amount);

        vm.stopPrank();

        // Assert
        uint256 assetsAfterRollover = ark.totalAssets();
        assertTrue(
            assetsAfterRollover > 0,
            "Ark should have assets after rollover"
        );
    }
    function test_SetSlippageBPS() public {
        uint256 newSlippageBPS = 100; // 1%

        vm.prank(governor);
        ark.setSlippageBPS(newSlippageBPS);

        assertEq(
            ark.slippageBPS(),
            newSlippageBPS,
            "Slippage BPS not updated correctly"
        );
    }

    function test_SetSlippageBPS_RevertOnInvalidValue() public {
        uint256 invalidSlippageBPS = 10001; // Over 100%

        vm.prank(governor);
        vm.expectRevert("Invalid slippage");
        ark.setSlippageBPS(invalidSlippageBPS);
    }

    function test_SetOracleDuration() public {
        uint32 newOracleDuration = 1800; // 30 minutes

        vm.prank(governor);
        ark.setOracleDuration(newOracleDuration);

        assertEq(
            ark.oracleDuration(),
            newOracleDuration,
            "Oracle duration not updated correctly"
        );
    }

    function test_SetOracleDuration_RevertOnInvalidValue() public {
        uint32 invalidOracleDuration = 899; // Less than 15 minutes

        vm.prank(governor);
        vm.expectRevert("Duration too low");
        ark.setOracleDuration(invalidOracleDuration);
    }

    function test_RevertWhenNoValidNextMarket() public {
        // Setup: Board some assets first
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 2 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), 2 * amount);
        ark.board(amount);
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
        vm.expectRevert("No valid next market");
        vm.prank(commander);
        ark.board(amount);
    }

    function test_RevertWhenOracleNotReady() public {
        // Setup: Board some assets first
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, 2 * amount);

        vm.startPrank(commander);
        usde.approve(address(ark), 2 * amount);
        ark.board(amount);
        vm.stopPrank();

        // Fast forward time past market expiry
        vm.warp(ark.marketExpiry() + 1);

        // Mock the oracle to be not ready
        vm.mockCall(
            address(ark.oracle()),
            abi.encodeWithSelector(PendlePYLpOracle.getOracleState.selector),
            abi.encode(true, 0, false)
        );

        // Attempt to trigger rollover
        vm.expectRevert("Oracle not ready");
        vm.prank(commander);
        ark.board(amount);
    }

    function test_AprToApy() public view {
        uint256 apr = 0.05 * 1e18; // 5% APR
        uint256 apy = ark.aprToApy(apr);

        // Expected APY for 5% APR is approximately 5.127%
        assertApproxEqRel(
            apy,
            0.05127 * 1e18,
            0.001e18,
            "APY calculation is incorrect"
        );
    }

    function test_TotalAssets() public {
        // Setup: Board some assets first
        uint256 amount = 1000 * 10 ** 18;
        deal(USDE, commander, amount);

        vm.startPrank(commander);
        usde.approve(address(ark), amount);
        ark.board(amount);
        vm.stopPrank();

        uint256 totalAssets = ark.totalAssets();
        assertApproxEqRel(
            totalAssets,
            amount,
            0.01e18,
            "Total assets should be close to deposited amount"
        );
    }
}
