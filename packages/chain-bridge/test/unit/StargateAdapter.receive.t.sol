// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

contract StargateAdapterReceiveTest is StargateAdapterSetupTest {
    bytes32 testTransferId = bytes32(uint256(12345));

    function setUp() public override {
        super.setUp();

        // Grant super keeper role to governor for operational functions
        useNetworkA();
        vm.prank(governor);
        accessManagerA.grantSuperKeeperRole(governor);

        useNetworkB();
        vm.prank(governor);
        accessManagerB.grantSuperKeeperRole(governor);
    }

    /*//////////////////////////////////////////////////////////////
                          OPERATION STATUS TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetOperationStatus() public {
        useNetworkA();

        // First, setup the mapping in the router to allow the adapter to update this operation
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            testTransferId,
            address(adapterA)
        );

        // Now setup a mock operation status in the router using the test helper
        BridgeRouterTestHelper(address(routerA)).setOperationStatus(
            testTransferId,
            BridgeTypes.OperationStatus.SENT
        );

        // Get operation status through adapter
        BridgeTypes.OperationStatus status = adapterA.getOperationStatus(
            testTransferId
        );

        // Verify status matches what was set
        assertEq(uint8(status), uint8(BridgeTypes.OperationStatus.SENT));
    }

    function testGetOperationStatusQueued() public {
        useNetworkA();

        // Setup the mapping in the router
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            testTransferId,
            address(adapterA)
        );

        // Set operation status to queued
        BridgeRouterTestHelper(address(routerA)).setOperationStatus(
            testTransferId,
            BridgeTypes.OperationStatus.QUEUED
        );

        // Get operation status through adapter
        BridgeTypes.OperationStatus status = adapterA.getOperationStatus(
            testTransferId
        );

        // Verify status matches what was set
        assertEq(uint8(status), uint8(BridgeTypes.OperationStatus.QUEUED));
    }

    function testGetOperationStatusFailed() public {
        useNetworkA();

        // Setup the mapping in the router
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            testTransferId,
            address(adapterA)
        );

        // Set operation status to failed
        BridgeRouterTestHelper(address(routerA)).setOperationStatus(
            testTransferId,
            BridgeTypes.OperationStatus.FAILED
        );

        // Get operation status through adapter
        BridgeTypes.OperationStatus status = adapterA.getOperationStatus(
            testTransferId
        );

        // Verify status matches what was set
        assertEq(uint8(status), uint8(BridgeTypes.OperationStatus.FAILED));
    }

    /*//////////////////////////////////////////////////////////////
                          BRIDGE ROUTER TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetBridgeRouter() public {
        useNetworkA();

        address newRouter = address(0x999);

        // Update bridge router as owner
        vm.prank(governor);
        adapterA.setBridgeRouter(newRouter);

        // Verify the router was updated
        assertEq(adapterA.bridgeRouter(), newRouter);
    }

    function testSetBridgeRouterUnauthorized() public {
        useNetworkA();

        address newRouter = address(0x999);

        // Try to update bridge router as unauthorized user
        vm.prank(user);
        vm.expectRevert();
        adapterA.setBridgeRouter(newRouter);
    }

    function testSetBridgeRouterZeroAddress() public {
        useNetworkA();

        // Try to set bridge router to zero address
        vm.prank(governor);
        vm.expectRevert(IBridgeAdapter.InvalidBridgeRouter.selector);
        adapterA.setBridgeRouter(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSPORT MODE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetDefaultTransportMode() public {
        useNetworkA();

        // Check initial value (should be true - taxi mode)
        assertEq(adapterA.defaultUseTaxi(), true);

        // Update to taxi mode
        vm.prank(governor);
        adapterA.setDefaultTransportMode(true);

        // Verify the value was updated
        assertEq(adapterA.defaultUseTaxi(), true);

        // Update back to bus mode
        vm.prank(governor);
        adapterA.setDefaultTransportMode(false);

        // Verify the value was updated
        assertEq(adapterA.defaultUseTaxi(), false);
    }

    function testSetDefaultTransportModeUnauthorized() public {
        useNetworkA();

        // Try to update transport mode as unauthorized user
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotSuperKeeper.selector,
                user
            )
        );
        adapterA.setDefaultTransportMode(true);
    }
}
