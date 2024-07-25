// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {ITipper} from "../../src/interfaces/ITipper.sol";
import {ITipperEvents} from "../../src/interfaces/ITipperEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract MockConfigurationManager is IConfigurationManager {
    address public tipJar;

    constructor(address _tipJar) {
        tipJar = _tipJar;
    }

    // Implement other IConfigurationManager functions with empty bodies
    function raft() external pure returns (address) {}
    function tipRate() external pure returns (uint8) {}
    function setRaft(address) external pure {}
    function setTipRate(uint8) external pure {}
}

contract TipperTest is Test, ITipperEvents {
    address public mockUser = address(1);
    FleetCommanderMock public fleetCommander;
    MockConfigurationManager public configManager;

    ERC20Mock public underlyingToken;
    address public tipJar;
    uint8 public initialTipRate;

    function setUp() public {
        underlyingToken = new ERC20Mock();
        tipJar = address(0x123);
        initialTipRate = 100; // 1%
        configManager = MockConfigurationManager(
            address(new MockConfigurationManagerImpl(tipJar))
        );
        fleetCommander = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            initialTipRate
        );
        vm.prank(address(fleetCommander));
        underlyingToken.approve(address(fleetCommander), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(fleetCommander.tipRate(), initialTipRate);
        assertEq(fleetCommander.tipJar(), tipJar);
        assertEq(fleetCommander.lastTipTimestamp(), block.timestamp);
    }

    function test_SetTipRate() public {
        uint8 newTipRate = 200; // 2%
        vm.expectEmit(true, true, false, true);
        emit TipRateUpdated(newTipRate);
        fleetCommander.setTipRate(newTipRate);
        assertEq(fleetCommander.tipRate(), newTipRate);
    }

    function test_SetTipJar() public {
        address newTipJar = address(0x456);
        MockConfigurationManager _configManager = MockConfigurationManager(
            address(new MockConfigurationManagerImpl(newTipJar))
        );
        FleetCommanderMock _fleetCommander = new FleetCommanderMock(
            address(underlyingToken),
            address(_configManager),
            initialTipRate
        );

        vm.expectEmit(true, true, false, true);
        emit TipJarUpdated(newTipJar);
        _fleetCommander.setTipJar();
        assertEq(_fleetCommander.tipJar(), newTipJar);
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
        emit TipAccrued(10050028723667921000000); // Approximately 1% of 1,000,000 over 1 year
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

        uint256 estimatedTip = fleetCommander.estimateAccruedTip();
        assertApproxEqRel(estimatedTip, 4978 ether, 0.01e18); // Approximately 0.4978% of 1,000,000 over 6 months
    }

    function test_TipRateCannotExceedOneHundredPercent() public {
        vm.expectRevert(
            abi.encodeWithSignature("TipRateCannotExceedOneHundredPercent()")
        );
        fleetCommander.setTipRate(10001); // 100.01%
    }

    function test_SetTipJarCannotBeZeroAddress() public {
        MockConfigurationManager _configManager = MockConfigurationManager(
            address(new MockConfigurationManagerImpl(address(0)))
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
        assertApproxEqRel(firstAccrual, 16.17 ether, 0.01e18);
        assertApproxEqRel(secondAccrual, 16.47 ether, 0.01e18);
    }
}

// Concrete implementation of MockConfigurationManager
contract MockConfigurationManagerImpl is MockConfigurationManager {
    constructor(address _tipJar) MockConfigurationManager(_tipJar) {}

    function setTipJar(address newTipJar) external override {
        tipJar = newTipJar;
    }
}
