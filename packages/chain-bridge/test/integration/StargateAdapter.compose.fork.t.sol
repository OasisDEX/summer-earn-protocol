// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";

import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";

import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {MockFleetProxy} from "../mocks/MockFleetProxy.sol";
import {MockStargateV2Pool} from "../mocks/MockStargateV2.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";

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
    CrossChainRegistry registryMainnet;
    CrossChainRegistry registryArbitrum;
    MockFleetProxy fleetProxyArbitrum;
    MockStargateV2Pool mockStargateMainnet;
    MockStargateV2Pool mockStargateArbitrum;

    address user = address(0x123);
    address governor = address(0x456);

    uint256 public constant FORK_BLOCK = 22145762;

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

        // Deploy and initialize CrossChainRegistry for mainnet
        registryMainnet = new CrossChainRegistry(
            address(accessManager),
            CHAIN_ID_MAINNET
        );

        routerMainnet = new BridgeRouterTestHelper(
            address(accessManager),
            address(registryMainnet)
        );

        registryMainnet.initializeBridgeConfiguration(
            address(routerMainnet),
            400000 // defaultGasLimit
        );

        adapterMainnet = new StargateAdapter(
            address(registryMainnet), // Use registry instead of config manager
            address(accessManager),
            LAYERZERO_ENDPOINT_MAINNET,
            address(0xdead) // Mock HarborCommand address for testing
        );

        // Configure mainnet adapter with basic chain support only
        adapterMainnet.mapEndpoint(CHAIN_ID_MAINNET, LZ_EID_MAINNET);
        // Don't add CHAIN_ID_ARBITRUM yet - will add after arbitrum adapter is deployed

        // Deploy mock Stargate contract for mainnet USDC
        mockStargateMainnet = new MockStargateV2Pool(USDC_MAINNET);

        // Add asset support for USDC on mainnet
        adapterMainnet.addSupportedAsset(
            USDC_MAINNET,
            address(mockStargateMainnet)
        );

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

        registryArbitrum = new CrossChainRegistry(
            address(accessManagerArb),
            CHAIN_ID_ARBITRUM
        );

        routerArbitrum = new BridgeRouterTestHelper(
            address(accessManagerArb),
            address(registryArbitrum)
        );

        registryArbitrum.initializeBridgeConfiguration(
            address(routerArbitrum),
            400000 // defaultGasLimit
        );

        adapterArbitrum = new StargateAdapter(
            address(registryArbitrum), // Use registry instead of config manager
            address(accessManagerArb),
            LAYERZERO_ENDPOINT_ARBITRUM,
            address(0xdead) // Mock HarborCommand address for testing
        );

        // Configure Arbitrum adapter with basic chain support only
        adapterArbitrum.mapEndpoint(CHAIN_ID_MAINNET, LZ_EID_MAINNET);
        adapterArbitrum.mapEndpoint(CHAIN_ID_ARBITRUM, LZ_EID_ARBITRUM);

        routerArbitrum.registerAdapter(address(adapterArbitrum));

        // Deploy fleet proxy on Arbitrum
        fleetProxyArbitrum = new MockFleetProxy(USDC_ARBITRUM);

        // Deploy mock Stargate contract for Arbitrum USDC
        mockStargateArbitrum = new MockStargateV2Pool(USDC_ARBITRUM);

        // Add asset support for USDC on Arbitrum
        adapterArbitrum.addSupportedAsset(
            USDC_ARBITRUM,
            address(mockStargateArbitrum)
        );

        vm.stopPrank();

        // Switch back to mainnet fork to set up the reverse relationship
        vm.selectFork(0);
        vm.startPrank(governor);

        adapterMainnet.mapEndpoint(CHAIN_ID_ARBITRUM, LZ_EID_ARBITRUM);
        registryMainnet.registerAdapterPeer(
            address(adapterMainnet),
            address(adapterArbitrum),
            CHAIN_ID_MAINNET,
            CHAIN_ID_ARBITRUM
        );

        vm.stopPrank();
    }

    function testUnauthorizedLzCompose() public {
        vm.selectFork(1); // Arbitrum fork

        // Create our custom compose message
        bytes memory customComposeMessage = abi.encode(
            address(fleetProxyArbitrum),
            1000e6,
            uint256(CHAIN_ID_MAINNET),
            bytes32("test-operation"),
            user
        );

        // Create the OFT-encoded compose message
        bytes memory oftEncodedMessage = OFTComposeMsgCodec.encode(
            uint64(1), // nonce
            uint32(LZ_EID_MAINNET), // source endpoint ID
            1000e6, // amount in local decimals
            customComposeMessage // No adapter address wrapping
        );

        // Should revert when called by non-endpoint
        // Use low-level call to work around bytes memory -> bytes calldata conversion
        vm.prank(user);
        bytes memory callData = abi.encodeWithSignature(
            "lzCompose(address,bytes32,bytes,address,bytes)",
            address(adapterMainnet),
            bytes32("test-guid"),
            oftEncodedMessage, // Use the properly encoded OFT message
            address(0),
            ""
        );

        (bool success, bytes memory returnData) = address(adapterArbitrum).call(
            callData
        );
        assertFalse(
            success,
            "lzCompose call should fail for unauthorized caller"
        );

        // Check that it reverted with Unauthorized error
        bytes4 unauthorizedSelector = BaseBridgeAdapter.Unauthorized.selector;

        // The return data should contain the revert reason
        assertTrue(returnData.length >= 4, "Should have revert data");
        bytes4 actualSelector;
        assembly {
            actualSelector := mload(add(returnData, 0x20))
        }
        assertEq(
            actualSelector,
            unauthorizedSelector,
            "Should revert with Unauthorized"
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
        assertTrue(
            adapterMainnet.CROSS_CHAIN_REGISTRY().getAdapterPeer(
                address(adapterMainnet),
                CHAIN_ID_ARBITRUM
            ) != address(0),
            "Arbitrum should be supported"
        );

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
}
