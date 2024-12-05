// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {Test, console} from "forge-std/Test.sol";

import {ITipperEvents} from "../../src/events/ITipperEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";

import {Tipper} from "../../src/contracts/Tipper.sol";

import {HarborCommand} from "../../src/contracts/HarborCommand.sol";

import {ConfigurationManagerImplMock, ConfigurationManagerMock} from "../mocks/ConfigurationManagerMock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract TipperTest is Test, ITipperEvents {
    using PercentageUtils for uint256;

    address public mockUser = address(1);
    address public governor = address(2);
    address public guardian = address(2);
    address public keeper = address(3);
    FleetCommanderMock public fleetCommander;
    ConfigurationManagerMock public configManager;
    ProtocolAccessManager public accessManager;
    ERC20Mock public underlyingToken;
    address public tipJar;
    Percentage public initialTipRate;
    TipperHarness public tipper;
    HarborCommand public harborCommand;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantKeeperRole(address(fleetCommander), keeper);
        harborCommand = new HarborCommand(address(accessManager));

        underlyingToken = new ERC20Mock();
        tipJar = address(0x123);

        initialTipRate = PercentageUtils.fromIntegerPercentage(1);
        configManager = ConfigurationManagerMock(
            address(
                new ConfigurationManagerImplMock(
                    tipJar,
                    address(0),
                    address(0),
                    address(harborCommand),
                    address(0)
                )
            )
        );
        fleetCommander = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            initialTipRate
        );
        vm.prank(address(fleetCommander));
        underlyingToken.approve(address(fleetCommander), type(uint256).max);
        tipper = new TipperHarness(address(configManager));
    }

    function test_InitialState() public view {
        assertTrue(fleetCommander.tipRate() == initialTipRate);
        assertEq(fleetCommander.tipJar(), tipJar);
        assertEq(fleetCommander.lastTipTimestamp(), block.timestamp);
    }

    function test_SetTipRate() public {
        Percentage newTipRate = PercentageUtils.fromIntegerPercentage(2);
        vm.expectEmit(true, true, false, true);
        emit TipRateUpdated(newTipRate);
        fleetCommander.setTipRate(newTipRate);
        assertTrue(fleetCommander.tipRate() == newTipRate);
    }

    function test_AccrueTip() public {
        uint256 initialDepositByUser = 1000000 ether;
        underlyingToken.mint(mockUser, initialDepositByUser);

        vm.startPrank(mockUser);
        underlyingToken.approve(address(fleetCommander), initialDepositByUser);
        fleetCommander.deposit(initialDepositByUser, mockUser);
        vm.stopPrank();

        // Warp time forward by 1 year
        vm.warp(block.timestamp + 365 days);

        vm.expectEmit(true, true, false, true);
        emit TipAccrued(10000000000000000000000); // Approximately 1% of 1,000,000 over 1 year
        uint256 accruedTip = fleetCommander.tip();

        assertApproxEqRel(accruedTip, 10050 ether, 0.01e18);
        assertEq(fleetCommander.lastTipTimestamp(), block.timestamp);
    }

    function test_TipRateCannotExceedFivePercent() public {
        vm.expectRevert(
            abi.encodeWithSignature("TipRateCannotExceedFivePercent()")
        );
        fleetCommander.setTipRate(PercentageUtils.fromIntegerPercentage(6));
    }

    function test_CompoundingEffect() public {
        uint256 initialDepositByUser = 10000 ether;
        underlyingToken.mint(mockUser, initialDepositByUser);

        vm.startPrank(mockUser);
        underlyingToken.approve(address(fleetCommander), initialDepositByUser);
        fleetCommander.deposit(initialDepositByUser, mockUser);
        vm.stopPrank();

        // Accrue tips for first 60 days
        vm.warp(60 days);
        uint256 firstAccrual = fleetCommander.tip();

        // Accrue tips for another 60 days (120 in total)
        vm.warp(120 days);
        uint256 secondAccrual = fleetCommander.tip();

        assertGt(secondAccrual, firstAccrual);
        assertApproxEqRel(firstAccrual, 16.45 ether, 0.01e18);
        assertApproxEqRel(secondAccrual, 16.47 ether, 0.01e18);
    }

    function test_NoTipAccrualForSmallAmounts() public {
        uint256 initialDepositByUser = 10000;
        underlyingToken.mint(mockUser, initialDepositByUser);

        vm.startPrank(mockUser);
        underlyingToken.approve(address(fleetCommander), initialDepositByUser);
        fleetCommander.deposit(initialDepositByUser, mockUser);
        vm.stopPrank();

        uint256 tipExpectedAfter1000minutes = tipper.exposed_calculateTip(
            fleetCommander.totalSupply(),
            1
        );
        assertEq(
            tipExpectedAfter1000minutes,
            0,
            "No tip should be accrued for small amounts"
        );

        uint256 tipExpectedAfter2000minutes = tipper.exposed_calculateTip(
            fleetCommander.totalSupply(),
            2000 minutes
        );
        uint256 initialLastTipTimestamp = fleetCommander.lastTipTimestamp();

        // Warp time forward by a small amount (e.g., 1 minute)
        vm.warp(block.timestamp + 1 minutes);

        uint256 tipAccruedAfter1Minute = fleetCommander.tip();

        assertEq(
            tipAccruedAfter1Minute,
            0,
            "No tip should be accrued for small amounts"
        );
        assertEq(
            fleetCommander.lastTipTimestamp(),
            initialLastTipTimestamp,
            "lastTipTimestamp should not be updated for zero tip accrual"
        );

        // for 1000 minutes there should be no tip accrued
        vm.warp(block.timestamp + 1000 minutes);
        uint256 tipAccruedAfter1000minutes = fleetCommander.tip();

        assertEq(
            tipAccruedAfter1000minutes,
            0,
            "No tip should be accrued for small amounts"
        );

        // there should be tip for 2000 minutes
        vm.warp(block.timestamp + 1000 minutes);

        // Ensure that estimateAccruedTip returns a non-zero value
        uint256 estimatedTipAfter2000minutes = fleetCommander.tip();
        assertEq(
            estimatedTipAfter2000minutes,
            tipExpectedAfter2000minutes,
            "Estimated tip should be greater than zero"
        );
    }
}

contract TipperHarness is Tipper {
    constructor(address) Tipper(PercentageUtils.fromIntegerPercentage(0)) {
        tipRate = PercentageUtils.fromIntegerPercentage(1); // 1%
    }

    function exposed_calculateTip(
        uint256 totalShares,
        uint256 timeElapsed
    ) public view returns (uint256) {
        return _calculateTip(totalShares, timeElapsed);
    }

    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {}

    function test_() public {}
}
