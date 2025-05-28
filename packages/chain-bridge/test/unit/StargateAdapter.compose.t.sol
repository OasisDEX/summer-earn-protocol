// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {ICrossChainAssetReceiver} from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import {MockFleetProxy} from "../mocks/MockFleetProxy.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

contract StargateAdapterComposeTest is StargateAdapterSetupTest {
    MockFleetProxy public fleetProxyA;
    MockFleetProxy public fleetProxyB;

    function setUp() public override {
        super.setUp();

        // Deploy fleet proxies
        useNetworkA();
        vm.startPrank(governor);
        fleetProxyA = new MockFleetProxy(address(tokenA));
        vm.stopPrank();

        useNetworkB();
        vm.startPrank(governor);
        fleetProxyB = new MockFleetProxy(address(tokenB));
        vm.stopPrank();

        useNetworkA();
    }

    function testLzComposeSuccess() public {
        useNetworkB(); // Test on destination chain

        // Setup test data
        bytes32 operationId = keccak256("test-operation");
        address fleetProxy = address(fleetProxyB);
        address asset = address(tokenB);
        uint256 amount = 1 ether;
        uint16 sourceChainId = CHAIN_ID_A;
        address originator = user;

        // Encode compose message
        bytes memory composeMessage = abi.encode(
            fleetProxy,
            asset,
            amount,
            sourceChainId,
            operationId,
            originator
        );

        // Mint tokens to the adapter (simulating Stargate delivery)
        tokenB.mint(address(adapterB), amount);

        // Expect the ComposedAssetHandled event
        vm.expectEmit(true, true, true, true);
        emit StargateAdapter.ComposedAssetHandled(
            operationId,
            fleetProxy,
            asset,
            amount,
            sourceChainId
        );

        // Simulate LayerZero endpoint calling lzCompose
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(adapterA), // Source adapter
            bytes32("test-guid"),
            composeMessage,
            address(0), // executor
            "" // extra data
        );

        // Verify fleet proxy received the call
        assertTrue(fleetProxyB.receivedAssets());
        assertEq(fleetProxyB.lastAsset(), asset);
        assertEq(fleetProxyB.lastAmount(), amount);
        assertEq(fleetProxyB.lastSourceChainId(), sourceChainId);

        // Verify tokens were transferred to FleetProxy
        assertEq(
            tokenB.balanceOf(address(fleetProxyB)),
            amount,
            "FleetProxy should have received tokens"
        );
        assertEq(
            tokenB.balanceOf(address(adapterB)),
            0,
            "Adapter should have no tokens left"
        );
    }

    function testLzComposeUnauthorizedCaller() public {
        useNetworkB();

        bytes memory composeMessage = abi.encode(
            address(fleetProxyB),
            address(tokenB),
            1 ether,
            CHAIN_ID_A,
            bytes32("test-operation"),
            user
        );

        // Should revert when called by non-endpoint
        vm.expectRevert(IBridgeAdapter.Unauthorized.selector);
        vm.prank(user); // Not the endpoint
        adapterB.lzCompose(
            address(adapterA),
            bytes32("test-guid"),
            composeMessage,
            address(0),
            ""
        );
    }

    function testTransferAssetWithCompose() public {
        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        // Setup adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Estimate fee
        (uint256 nativeFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Transfer tokens to router and approve
        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);

        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Calculate operation ID
        bytes32 expectedOperationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                address(fleetProxyB), // recipient is fleet proxy
                block.timestamp,
                block.number
            )
        );

        // Setup router
        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            expectedOperationId,
            address(adapterA)
        );

        // Mock Stargate to expect compose message
        bytes memory expectedComposeMsg = abi.encode(
            address(fleetProxyB), // FleetProxy address
            address(tokenA), // Asset address
            1 ether, // Amount being sent
            uint16(CHAIN_ID_A), // Source chain ID
            expectedOperationId, // Operation ID for tracking
            user // Original sender
        );

        stargateA.setExpectedComposeMsg(expectedComposeMsg);

        // Execute transfer
        vm.prank(address(routerA));
        adapterA.transferAsset{value: nativeFee}(
            expectedOperationId,
            CHAIN_ID_B,
            address(tokenA),
            address(fleetProxyB), // Send to fleet proxy
            1 ether,
            user,
            adapterParams
        );

        // Verify compose message was set correctly
        assertTrue(stargateA.composeMsgWasSet());
    }

    function testComposeGasLimitConfiguration() public {
        useNetworkA();

        // Test setting compose gas limit
        uint256 newGasLimit = 250000;

        vm.expectEmit(true, false, false, true);
        emit StargateAdapter.ComposeGasLimitUpdated(newGasLimit);

        vm.prank(governor);
        adapterA.setComposeGasLimit(newGasLimit);

        assertEq(adapterA.composeGasLimit(), newGasLimit);
    }

    function testComposeGasLimitBounds() public {
        useNetworkA();

        // Test minimum bound
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
        vm.prank(governor);
        adapterA.setComposeGasLimit(50000); // Below MIN_COMPOSE_GAS

        // Test maximum bound
        vm.expectRevert(IBridgeAdapter.InvalidParams.selector);
        vm.prank(governor);
        adapterA.setComposeGasLimit(600000); // Above MAX_COMPOSE_GAS
    }

    function testComposeGasLimitUnauthorized() public {
        useNetworkA();

        vm.expectRevert();
        vm.prank(user); // Not owner
        adapterA.setComposeGasLimit(200000);
    }

    function testLzComposeWithInvalidMessage() public {
        useNetworkB();

        // Invalid message (wrong encoding)
        bytes memory invalidMessage = abi.encode(
            address(fleetProxyB),
            address(tokenB)
            // Missing required fields
        );

        vm.expectRevert(); // Should revert on decode
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(adapterA),
            bytes32("test-guid"),
            invalidMessage,
            address(0),
            ""
        );
    }

    function testLzComposeFleetProxyRevert() public {
        useNetworkB();

        // Setup fleet proxy to revert
        fleetProxyB.setShouldRevert(true);

        // Mint tokens to the adapter (simulating Stargate delivery)
        tokenB.mint(address(adapterB), 1 ether);

        bytes memory composeMessage = abi.encode(
            address(fleetProxyB),
            address(tokenB),
            1 ether,
            CHAIN_ID_A,
            bytes32("test-operation"),
            user
        );

        // Should revert when fleet proxy reverts
        vm.expectRevert("MockFleetProxy: forced revert");
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(adapterA),
            bytes32("test-guid"),
            composeMessage,
            address(0),
            ""
        );
    }

    function testEndToEndComposeFlow() public {
        // This test simulates the full flow:
        // 1. Send tokens from Chain A to Chain B with compose message
        // 2. Verify compose message is properly formatted
        // 3. Simulate LayerZero delivering the compose message
        // 4. Verify FleetProxy receives the assets

        useNetworkA();
        vm.deal(address(routerA), 1 ether);

        // Setup for transfer
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Prepare tokens
        vm.prank(user);
        tokenA.transfer(address(routerA), 1 ether);
        vm.prank(address(routerA));
        tokenA.approve(address(adapterA), 1 ether);

        // Calculate operation ID
        bytes32 operationId = keccak256(
            abi.encode(
                CHAIN_ID_A,
                CHAIN_ID_B,
                address(tokenA),
                1 ether,
                address(fleetProxyB),
                block.timestamp,
                block.number
            )
        );

        BridgeRouterTestHelper(address(routerA)).setOperationToAdapter(
            operationId,
            address(adapterA)
        );

        // Execute transfer (this should create compose message)
        (uint256 nativeFee, ) = adapterA.estimateFee(
            CHAIN_ID_B,
            address(tokenA),
            1 ether,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        vm.prank(address(routerA));
        adapterA.transferAsset{value: nativeFee}(
            operationId,
            CHAIN_ID_B,
            address(tokenA),
            address(fleetProxyB),
            1 ether,
            user,
            adapterParams
        );

        // Verify compose message was created
        assertTrue(stargateA.composeMsgWasSet());

        // Now simulate the compose execution on Chain B
        useNetworkB();

        // Mint tokens to adapter B (simulating Stargate delivery)
        tokenB.mint(address(adapterB), 1 ether);

        // Create the compose message that would be sent by Stargate
        bytes memory composeMessage = abi.encode(
            address(fleetProxyB), // FleetProxy address
            address(tokenB), // Asset address (mapped to chain B)
            1 ether, // Amount
            uint16(CHAIN_ID_A), // Source chain ID
            operationId, // Operation ID
            user // Originator
        );

        // Simulate LayerZero calling lzCompose
        vm.prank(lzEndpointB);
        adapterB.lzCompose(
            address(adapterA),
            bytes32("test-guid"),
            composeMessage,
            address(0),
            ""
        );

        // Verify FleetProxy received the assets
        assertTrue(fleetProxyB.receivedAssets());
        assertEq(fleetProxyB.lastAsset(), address(tokenB));
        assertEq(fleetProxyB.lastAmount(), 1 ether);
        assertEq(fleetProxyB.lastSourceChainId(), CHAIN_ID_A);

        // Verify tokens were transferred to FleetProxy
        assertEq(
            tokenB.balanceOf(address(fleetProxyB)),
            1 ether,
            "FleetProxy should have received tokens"
        );
        assertEq(
            tokenB.balanceOf(address(adapterB)),
            0,
            "Adapter should have no tokens left"
        );
    }
}
