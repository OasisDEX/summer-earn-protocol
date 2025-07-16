// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

contract StargateAdapterReceiveTest is StargateAdapterSetupTest {
    bytes32 testTransferId = bytes32(uint256(12345));

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
        vm.expectRevert();
        adapterA.setDefaultTransportMode(true);
    }

    /*//////////////////////////////////////////////////////////////
                          CONFIG MANAGER INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCrossChainRegistryFromRegistry() public {
        useNetworkA();

        // Verify cross chain registry is accessible through the adapter
        address adapterRegistry = adapterA.crossChainRegistry();
        address expectedRegistry = address(registryA);

        assertEq(adapterRegistry, expectedRegistry);
    }

    function testDefaultGasLimitFromRegistry() public {
        useNetworkA();

        // Verify default gas limit is accessible through the adapter
        uint256 adapterGasLimit = adapterA.defaultGasLimit();
        uint256 registryGasLimit = registryA.defaultGasLimit();

        assertEq(adapterGasLimit, registryGasLimit);
        assertEq(adapterGasLimit, 400000); // From setup
    }

    function testComposeGasLimitUsesDefault() public {
        useNetworkA();

        // Set compose gas limit to 0 to test fallback to default
        vm.prank(governor);
        adapterA.setComposeGasLimit(0);

        // Should use default gas limit from registry
        assertEq(adapterA.composeGasLimit(), registryA.defaultGasLimit());
    }
}
