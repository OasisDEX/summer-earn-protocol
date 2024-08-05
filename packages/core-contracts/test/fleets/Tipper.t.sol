// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {ITipper} from "../../src/interfaces/ITipper.sol";
import {ITipperEvents} from "../../src/events/ITipperEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Tipper} from "../../src/contracts/Tipper.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {Percentage} from "../../src/types/Percentage.sol";
import {ConfigurationManagerMock} from "../mocks/ConfigurationManagerMock.sol";

contract TipperTest is Test, ITipperEvents {
    using PercentageUtils for uint256;

    address public mockUser = address(1);
    FleetCommanderMock public fleetCommander;
    ConfigurationManagerMock public configManager;

    ERC20Mock public underlyingToken;
    address public tipJar;
    Percentage public initialTipRate;
    TipperHarness public tipper;

    function setUp() public {
        underlyingToken = new ERC20Mock();
        tipJar = address(0x123);
        initialTipRate = PercentageUtils.fromDecimalPercentage(1);
        configManager = ConfigurationManagerMock(
            address(new ConfigurationManagerImplMock(tipJar))
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
        assertEq(address(fleetCommander.manager()), address(configManager));
        assertTrue(fleetCommander.tipRate() == initialTipRate);
        assertEq(fleetCommander.tipJar(), tipJar);
        assertEq(fleetCommander.lastTipTimestamp(), block.timestamp);
    }

    function test_SetTipRate() public {
        Percentage newTipRate = PercentageUtils.fromDecimalPercentage(2);
        vm.expectEmit(true, true, false, true);
        emit TipRateUpdated(newTipRate);
        fleetCommander.setTipRate(newTipRate);
        assertTrue(fleetCommander.tipRate() == newTipRate);
    }

    function test_SetTipJar() public {
        address newTipJar = address(0x456);
        vm.mockCall(
            address(configManager),
            abi.encodeWithSelector(IConfigurationManager.tipJar.selector),
            abi.encode(newTipJar)
        );

        vm.expectEmit(true, true, false, true);
        emit TipJarUpdated(newTipJar);
        fleetCommander.setTipJar();
        assertEq(fleetCommander.tipJar(), newTipJar);
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
        emit TipAccrued(10050167082308619770000); // Approximately 1% of 1,000,000 over 1 year
        uint256 accruedTip = fleetCommander.tip();

        assertApproxEqRel(accruedTip, 10050 ether, 0.01e18);
        assertEq(fleetCommander.lastTipTimestamp(), block.timestamp);
    }

    function test_EstimateAccruedTip() public {
        uint256 initialDepositByUser = 1000000 ether;
        underlyingToken.mint(mockUser, initialDepositByUser);

        vm.startPrank(mockUser);
        underlyingToken.approve(address(fleetCommander), initialDepositByUser);
        fleetCommander.deposit(initialDepositByUser, mockUser);
        vm.stopPrank();

        // Warp time forward by 6 months
        vm.warp(block.timestamp + 182.5 days);

        uint256 estimatedTipAfter2000minutes = fleetCommander
            .estimateAccruedTip();
        assertApproxEqRel(estimatedTipAfter2000minutes, 4978 ether, 0.01e18); // Approximately 0.4978% of 1,000,000 over 6 months
    }

    function test_TipRateCannotExceedOneHundredPercent() public {
        vm.expectRevert(
            abi.encodeWithSignature("TipRateCannotExceedOneHundredPercent()")
        );
        fleetCommander.setTipRate(PercentageUtils.fromDecimalPercentage(101));
    }

    function test_SetTipJarCannotBeZeroAddress() public {
        ConfigurationManagerMock _configManager = ConfigurationManagerMock(
            address(new ConfigurationManagerImplMock(address(0)))
        );
        FleetCommanderMock _fleetCommander = new FleetCommanderMock(
            address(underlyingToken),
            address(_configManager),
            initialTipRate
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidTipJarAddress()"));
        _fleetCommander.setTipJar();
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
        uint256 estimatedTipAfter2000minutes = fleetCommander
            .estimateAccruedTip();
        assertEq(
            estimatedTipAfter2000minutes,
            tipExpectedAfter2000minutes,
            "Estimated tip should be greater than zero"
        );
    }
}

contract ConfigurationManagerImplMock is ConfigurationManagerMock {
    constructor(address _tipJar) ConfigurationManagerMock(_tipJar) {}

    function setTipJar(address newTipJar) external override {
        tipJar = newTipJar;
    }
}

contract TipperHarness is Tipper {
    constructor(
        address configurationManager
    ) Tipper(configurationManager, PercentageUtils.fromDecimalPercentage(0)) {
        tipRate = PercentageUtils.fromDecimalPercentage(1); // 1%
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
}
