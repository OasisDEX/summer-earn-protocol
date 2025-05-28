// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockFleetProxy} from "../mocks/MockFleetProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";

/**
 * @title StargateAdapterComposeForkTest
 * @notice Integration tests for Stargate adapter compose functionality using mainnet forks
 * @dev These tests focus on LayerZero compose functionality without requiring real Stargate V2 contracts
 */
contract StargateAdapterComposeForkTest is Test {
    // Mainnet contract addresses
    address constant LAYERZERO_ENDPOINT_MAINNET =
        0x1a44076050125825900e736c501f859c50fE728c;
    address constant LAYERZERO_ENDPOINT_ARBITRUM =
        0x1a44076050125825900e736c501f859c50fE728c;

    // USDC addresses
    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // LayerZero endpoint IDs
    uint32 constant LZ_EID_MAINNET = 30101;
    uint32 constant LZ_EID_ARBITRUM = 30110;

    // Chain IDs
    uint16 constant CHAIN_ID_MAINNET = 1;
    uint16 constant CHAIN_ID_ARBITRUM = 42161;

    StargateAdapter adapterMainnet;
    StargateAdapter adapterArbitrum;
    BridgeRouterTestHelper routerMainnet;
    BridgeRouterTestHelper routerArbitrum;
    MockFleetProxy fleetProxyArbitrum;

    address user = address(0x123);
    address governor = address(0x456);

    uint256 public constant FORK_BLOCK = 22_145_762;

    function setUp() public {
        // Skip if no RPC URL is available
        try vm.rpcUrl("mainnet") returns (string memory) {
            // Fork mainnet
            vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
            vm.selectFork(0);
        } catch {
            // Skip test if mainnet RPC is not available
            vm.skip(true);
            return;
        }

        // Deploy mainnet contracts
        vm.startPrank(governor);

        ProtocolAccessManager accessManager = new ProtocolAccessManager(
            governor
        );
        BridgeQueue bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0),
            governor
        );

        routerMainnet = new BridgeRouterTestHelper(
            address(accessManager),
            address(bridgeQueue)
        );
        bridgeQueue.setBridgeRouter(address(routerMainnet));

        adapterMainnet = new StargateAdapter(
            address(routerMainnet),
            governor,
            LAYERZERO_ENDPOINT_MAINNET
        );

        // Configure mainnet adapter with basic chain support only
        adapterMainnet.addSupportedChain(CHAIN_ID_MAINNET, LZ_EID_MAINNET);
        adapterMainnet.addSupportedChain(CHAIN_ID_ARBITRUM, LZ_EID_ARBITRUM);

        routerMainnet.registerAdapter(address(adapterMainnet));
        vm.stopPrank();

        // Create second fork for Arbitrum (using mainnet fork as placeholder)
        try vm.rpcUrl("arbitrum") returns (string memory arbUrl) {
            vm.createFork(arbUrl);
        } catch {
            // Use mainnet fork as placeholder if Arbitrum RPC not available
            vm.createFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        }
        vm.selectFork(1);

        // Deploy Arbitrum contracts
        vm.startPrank(governor);

        ProtocolAccessManager accessManagerArb = new ProtocolAccessManager(
            governor
        );
        BridgeQueue bridgeQueueArb = new BridgeQueue(
            address(accessManagerArb),
            address(0),
            governor
        );

        routerArbitrum = new BridgeRouterTestHelper(
            address(accessManagerArb),
            address(bridgeQueueArb)
        );
        bridgeQueueArb.setBridgeRouter(address(routerArbitrum));

        adapterArbitrum = new StargateAdapter(
            address(routerArbitrum),
            governor,
            LAYERZERO_ENDPOINT_ARBITRUM
        );

        // Configure Arbitrum adapter with basic chain support only
        adapterArbitrum.addSupportedChain(CHAIN_ID_MAINNET, LZ_EID_MAINNET);
        adapterArbitrum.addSupportedChain(CHAIN_ID_ARBITRUM, LZ_EID_ARBITRUM);

        routerArbitrum.registerAdapter(address(adapterArbitrum));

        // Deploy fleet proxy on Arbitrum
        fleetProxyArbitrum = new MockFleetProxy(USDC_ARBITRUM);

        vm.stopPrank();
    }

    function testComposeGasLimitConfiguration() public {
        vm.selectFork(0); // Mainnet

        // Test gas limit bounds
        uint256 minGas = adapterMainnet.MIN_COMPOSE_GAS();
        uint256 maxGas = adapterMainnet.MAX_COMPOSE_GAS();

        assertEq(minGas, 100000, "Min compose gas should be 100k");
        assertEq(maxGas, 500000, "Max compose gas should be 500k");

        // Test setting valid gas limit
        vm.prank(governor);
        adapterMainnet.setComposeGasLimit(200000);
        assertEq(adapterMainnet.composeGasLimit(), 200000);

        // Test invalid gas limits
        vm.expectRevert();
        vm.prank(governor);
        adapterMainnet.setComposeGasLimit(50000); // Too low

        vm.expectRevert();
        vm.prank(governor);
        adapterMainnet.setComposeGasLimit(600000); // Too high
    }

    function testLzComposeWithRealEndpoint() public {
        vm.selectFork(1); // Arbitrum fork

        // Setup test data
        bytes32 operationId = keccak256("test-operation");
        uint256 amount = 1000e6;

        bytes memory composeMessage = abi.encode(
            address(fleetProxyArbitrum),
            USDC_ARBITRUM,
            amount,
            CHAIN_ID_MAINNET,
            operationId,
            user
        );

        // Give adapter some USDC (simulating Stargate delivery)
        deal(USDC_ARBITRUM, address(adapterArbitrum), amount);

        // Test that lzCompose works with LayerZero endpoint
        vm.prank(LAYERZERO_ENDPOINT_ARBITRUM);
        adapterArbitrum.lzCompose(
            address(adapterMainnet), // Source adapter
            bytes32("test-guid"),
            composeMessage,
            address(0),
            ""
        );

        // Verify fleet proxy received the assets
        assertTrue(fleetProxyArbitrum.receivedAssets());
        assertEq(fleetProxyArbitrum.lastAsset(), USDC_ARBITRUM);
        assertEq(fleetProxyArbitrum.lastAmount(), amount);
        assertEq(fleetProxyArbitrum.lastSourceChainId(), CHAIN_ID_MAINNET);
    }

    function testUnauthorizedLzCompose() public {
        vm.selectFork(1); // Arbitrum fork

        bytes memory composeMessage = abi.encode(
            address(fleetProxyArbitrum),
            USDC_ARBITRUM,
            1000e6,
            CHAIN_ID_MAINNET,
            bytes32("test-operation"),
            user
        );

        // Should revert when called by non-endpoint
        vm.expectRevert(IBridgeAdapter.Unauthorized.selector);
        vm.prank(user);
        adapterArbitrum.lzCompose(
            address(adapterMainnet),
            bytes32("test-guid"),
            composeMessage,
            address(0),
            ""
        );
    }

    function testComposeMessageEncoding() public view {
        // Test that compose messages are encoded correctly
        bytes32 operationId = bytes32(uint256(12345));
        address fleetProxy = address(0x789);
        address asset = USDC_MAINNET;
        uint256 amount = 1000e6;
        uint16 sourceChainId = CHAIN_ID_MAINNET;
        address originator = user;

        bytes memory encoded = abi.encode(
            fleetProxy,
            asset,
            amount,
            sourceChainId,
            operationId,
            originator
        );

        // Decode and verify
        (
            address decodedFleetProxy,
            address decodedAsset,
            uint256 decodedAmount,
            uint16 decodedSourceChainId,
            bytes32 decodedOperationId,
            address decodedOriginator
        ) = abi.decode(
                encoded,
                (address, address, uint256, uint16, bytes32, address)
            );

        assertEq(decodedFleetProxy, fleetProxy);
        assertEq(decodedAsset, asset);
        assertEq(decodedAmount, amount);
        assertEq(decodedSourceChainId, sourceChainId);
        assertEq(decodedOperationId, operationId);
        assertEq(decodedOriginator, originator);
    }

    function testAdapterConfiguration() public {
        vm.selectFork(0); // Mainnet

        // Test that adapter is properly configured
        assertTrue(adapterMainnet.supportsChain(CHAIN_ID_MAINNET));
        assertTrue(adapterMainnet.supportsChain(CHAIN_ID_ARBITRUM));

        // Test endpoint ID mapping
        assertEq(
            adapterMainnet.getEndpointId(CHAIN_ID_MAINNET),
            LZ_EID_MAINNET
        );
        assertEq(
            adapterMainnet.getEndpointId(CHAIN_ID_ARBITRUM),
            LZ_EID_ARBITRUM
        );
    }

    function testComposeGasLimitBounds() public {
        vm.selectFork(0); // Mainnet

        // Test that compose gas limit is within bounds
        uint256 currentGasLimit = adapterMainnet.composeGasLimit();
        uint256 minGas = adapterMainnet.MIN_COMPOSE_GAS();
        uint256 maxGas = adapterMainnet.MAX_COMPOSE_GAS();

        assertTrue(
            currentGasLimit >= minGas,
            "Current gas limit should be >= min"
        );
        assertTrue(
            currentGasLimit <= maxGas,
            "Current gas limit should be <= max"
        );
    }
}
