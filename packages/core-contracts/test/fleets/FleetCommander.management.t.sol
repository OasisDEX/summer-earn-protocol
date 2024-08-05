// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderArkAlreadyExists, FleetCommanderRebalanceAmountZero, FleetCommanderInvalidSourceArk, FleetCommanderInvalidArkAddress, FleetCommanderNoExcessFunds, FleetCommanderInvalidBufferAdjustment, FleetCommanderInsufficientBuffer, FleetCommanderCantRebalanceToArk, FleetCommanderArkNotFound, FleetCommanderArkMaxAllocationZero, FleetCommanderArkMaxAllocationGreaterThanZero, FleetCommanderArkAssetsNotZero, FleetCommanderTransfersDisabled} from "../../src/errors/FleetCommanderErrors.sol";
import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {Percentage} from "../../src/types/Percentage.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ManagementTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
    }

    function testConstructorInitialization() public {
        FleetCommanderParams memory params = FleetCommanderParams({
            configurationManager: address(configurationManager),
            accessManager: address(accessManager),
            initialArks: new address[](0),
            initialMinimumFundsBufferBalance: 1000,
            initialRebalanceCooldown: 1 hours,
            asset: address(mockToken),
            name: "Fleet Commander",
            symbol: "FC",
            initialMinimumPositionWithdrawal: Percentage.wrap(0),
            initialMaximumBufferWithdrawal: Percentage.wrap(0),
            depositCap: 10000,
            bufferArk: bufferArkAddress,
            initialTipRate: Percentage.wrap(0)
        });

        FleetCommander newFleetCommander = new FleetCommander(params);

        assertEq(newFleetCommander.minFundsBufferBalance(), 1000);
        assertEq(newFleetCommander.depositCap(), 10000);
        assertEq(address(newFleetCommander.bufferArk()), bufferArkAddress);
        assertTrue(newFleetCommander.isArkActive(bufferArkAddress));
    }

    function testGetArks() public {
        address[] memory arks = fleetCommander.getArks();
        assertEq(arks.length, 3);
        assertEq(arks[0], address(mockArk1));
        assertEq(arks[1], address(mockArk2));
        assertEq(arks[2], address(mockArk3));
    }

    function testSetMaxAllocationArkNotFound() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0x123)
            )
        );
        fleetCommander.setMaxAllocation(address(0x123), 1000);
    }

    function testSetMinBufferBalance() public {
        uint256 newBalance = 2000;
        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit IFleetCommanderEvents.FleetCommanderMinFundsBufferBalanceUpdated(
            newBalance
        );
        fleetCommander.setMinBufferBalance(newBalance);
        assertEq(fleetCommander.minFundsBufferBalance(), newBalance);
    }

    function testTransferDisabled() public {
        vm.expectRevert(FleetCommanderTransfersDisabled.selector);
        fleetCommander.transfer(address(0x123), 100);
    }

    function testRemoveArkWithNonZeroAllocation() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkMaxAllocationGreaterThanZero.selector,
                address(mockArk1)
            )
        );
        fleetCommander.removeArk(address(mockArk1));
    }

    function testRemoveSuccessful() public {
        // First, set max allocation to 0
        vm.prank(governor);
        fleetCommander.setMaxAllocation(address(mockArk1), 0);

        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit IFleetCommanderEvents.ArkRemoved(address(mockArk1));
        fleetCommander.removeArk(address(mockArk1));
        assertEq(fleetCommander.getArks().length, 2);
        assertEq(fleetCommander.isArkActive(address(mockArk1)), false);
    }

    function testRemoveArkWithNonZeroAssets() public {
        // First, set max allocation to 0
        vm.prank(governor);
        fleetCommander.setMaxAllocation(address(mockArk1), 0);

        // Mock non-zero assets
        mockToken.mint(address(mockArk1), 1000);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkAssetsNotZero.selector,
                address(mockArk1)
            )
        );
        fleetCommander.removeArk(address(mockArk1));
    }

    function testRebalanceWithInvalidArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(0),
            toArk: address(mockArk1),
            amount: 100
        });

        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function testRebalanceToArkWithZeroMaxAllocation() public {
        // Set max allocation of mockArk1 to 0
        vm.prank(governor);
        fleetCommander.setMaxAllocation(address(mockArk1), 0);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: address(mockArk1),
            amount: 100
        });

        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkMaxAllocationZero.selector,
                address(mockArk1)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function testSetDepositCap() public {
        uint256 newDepositCap = 10000;
        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit IFleetCommanderEvents.DepositCapUpdated(newDepositCap);
        fleetCommander.setDepositCap(newDepositCap);
        assertEq(fleetCommander.depositCap(), newDepositCap);
    }

    function testAddArkWithAddressZero() public {
        vm.expectRevert(FleetCommanderInvalidArkAddress.selector);
        vm.prank(governor);
        fleetCommander.addArk(address(0));
    }

    function testAddAlreadyExistingArk() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkAlreadyExists.selector,
                address(mockArk1)
            )
        );
        vm.prank(governor);
        fleetCommander.addArk(address(mockArk1));
    }

    function testRemoveNotExistingArk() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.removeArk(address(0x123));
    }
}
