// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";

import {FleetCommanderArkAlreadyExists, FleetCommanderArkAssetsNotZero, FleetCommanderArkDepositCapGreaterThanZero, FleetCommanderArkDepositCapZero, FleetCommanderArkNotFound, FleetCommanderCantRebalanceToArk, FleetCommanderInsufficientBuffer, FleetCommanderInvalidArkAddress, FleetCommanderInvalidBufferAdjustment, FleetCommanderInvalidSourceArk, FleetCommanderNoExcessFunds, FleetCommanderRebalanceAmountZero, FleetCommanderTransfersDisabled} from "../../src/errors/FleetCommanderErrors.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {ArkTestHelpers, IArk} from "../helpers/ArkHelpers.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {Test} from "forge-std/Test.sol";

import {IArkEvents} from "../../src/events/IArkEvents.sol";
import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

contract ManagementTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
    }

    function test_ConstructorInitialization() public {
        FleetCommanderParams memory params = FleetCommanderParams({
            configurationManager: address(configurationManager),
            accessManager: address(accessManager),
            initialArks: new address[](0),
            initialMinimumBufferBalance: 1000,
            initialRebalanceCooldown: 1 hours,
            asset: address(mockToken),
            name: "Fleet Commander",
            symbol: "FC",
            depositCap: 10000,
            bufferArk: bufferArkAddress,
            initialTipRate: Percentage.wrap(0)
        });

        FleetCommander newFleetCommander = new FleetCommander(params);
        (
            IArk bufferArk,
            uint256 minimumBufferBalance,
            uint256 depositCap
        ) = newFleetCommander.config();

        assertEq(minimumBufferBalance, 1000);
        assertEq(depositCap, 10000);
        assertEq(address(bufferArk), bufferArkAddress);
        assertTrue(newFleetCommander.isArkActive(bufferArkAddress));
    }

    function test_GetArks() public view {
        address[] memory arks = fleetCommander.getArks();
        assertEq(arks.length, 4);
        assertEq(arks[0], address(mockArk1));
        assertEq(arks[1], address(mockArk2));
        assertEq(arks[2], address(mockArk3));
        assertEq(arks[3], address(mockArk4));
    }

    function test_SetMaxAllocationArkNotFound() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0x123)
            )
        );
        fleetCommander.setArkDepositCap(address(0x123), 1000);
    }

    function test_SetMinBufferBalance() public {
        uint256 newBalance = 2000;

        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit IFleetCommanderEvents.FleetCommanderminimumBufferBalanceUpdated(
            newBalance
        );
        fleetCommander.setMinimumBufferBalance(newBalance);

        (, uint256 minimumBufferBalance, ) = fleetCommander.config();
        assertEq(minimumBufferBalance, newBalance);
    }

    function test_TransferDisabled() public {
        vm.expectRevert(FleetCommanderTransfersDisabled.selector);
        fleetCommander.transfer(address(0x123), 100);
    }

    function test_TransferFromDisabled() public {
        vm.expectRevert(FleetCommanderTransfersDisabled.selector);
        fleetCommander.transferFrom(address(this), address(0x123), 100);
    }

    function test_RemoveArkWithNonZeroAllocation() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkDepositCapGreaterThanZero.selector,
                address(mockArk1)
            )
        );
        fleetCommander.removeArk(address(mockArk1));
    }

    function test_RemoveSuccessful() public {
        // First, set max allocation to 0
        uint256 initialArksCount = fleetCommander.getArks().length;
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(mockArk1), 0);

        vm.prank(governor);
        vm.expectEmit(false, false, false, true);
        emit IFleetCommanderEvents.ArkRemoved(address(mockArk1));
        fleetCommander.removeArk(address(mockArk1));
        assertEq(fleetCommander.getArks().length, initialArksCount - 1);
        assertEq(fleetCommander.isArkActive(address(mockArk1)), false);
    }

    function test_RemoveArkWithNonZeroAssets() public {
        // First, set max allocation to 0
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(mockArk1), 0);

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

    function test_RebalanceWithInvalidArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(0),
            toArk: address(mockArk1),
            amount: 100,
            boardData: bytes(""),
            disembarkData: bytes("")
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

    function test_RebalanceToArkWithZeroMaxAllocation() public {
        // Set max allocation of mockArk1 to 0
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(mockArk1), 0);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(mockArk2),
            toArk: address(mockArk1),
            amount: 100,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkDepositCapZero.selector,
                address(mockArk1)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_SetDepositCap() public {
        uint256 newDepositCap = 10000;
        vm.prank(governor);
        vm.expectEmit();
        emit IFleetCommanderEvents.DepositCapUpdated(newDepositCap);

        fleetCommander.setFleetDepositCap(newDepositCap);

        (, , uint256 depositCap) = fleetCommander.config();
        assertEq(depositCap, newDepositCap);
    }

    function test_setArkDepositCap() public {
        uint256 newDepositCap = 10000;
        vm.prank(governor);
        vm.expectEmit();
        emit IArkEvents.DepositCapUpdated(newDepositCap);
        fleetCommander.setArkDepositCap(address(mockArk2), newDepositCap);
        assertEq(mockArk2.depositCap(), newDepositCap);
    }

    function test_updateRebalanceCooldown_ShouldFail() public {
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", keeper)
        );
        fleetCommander.updateRebalanceCooldown(0);
    }

    function test_SetArkDepositCapInvalidArk_ShouldFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkDepositCap(address(0x123), 1000);
    }

    function test_SetArkMoveToMax() public {
        uint256 maxMoveTo = 1000;
        vm.prank(governor);
        vm.expectEmit();
        emit IArkEvents.MaxRebalanceInflowUpdated(maxMoveTo);
        fleetCommander.setArkMaxRebalanceInflow(address(mockArk2), maxMoveTo);

        assertEq(mockArk2.maxRebalanceInflow(), maxMoveTo);
    }

    function test_SetArkMoveToMaxInvalidArk_ShouldFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkMaxRebalanceInflow(
            address(0x123),
            type(uint256).max
        );
    }

    function test_SetArkMoveMaxRebalanceOutflow() public {
        uint256 maxMoveFrom = 1000;
        vm.prank(governor);
        vm.expectEmit();
        emit IArkEvents.MaxRebalanceOutflowUpdated(maxMoveFrom);
        fleetCommander.setArkMaxRebalanceOutflow(
            address(mockArk2),
            maxMoveFrom
        );

        assertEq(mockArk2.maxRebalanceOutflow(), maxMoveFrom);
    }

    function test_SetArkMoveMaxRebalanceOutflowInvalidArk_ShouldFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkNotFound.selector,
                address(0x123)
            )
        );
        vm.prank(governor);
        fleetCommander.setArkMaxRebalanceOutflow(
            address(0x123),
            type(uint256).max
        );
    }

    function test_AddArkWithAddressZero() public {
        vm.expectRevert(FleetCommanderInvalidArkAddress.selector);
        vm.prank(governor);
        fleetCommander.addArk(address(0));
    }

    function test_AddAlreadyExistingArk() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkAlreadyExists.selector,
                address(mockArk1)
            )
        );
        vm.prank(governor);
        fleetCommander.addArk(address(mockArk1));
    }

    function test_RemoveNotExistingArk() public {
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
