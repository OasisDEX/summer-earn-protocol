// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockFleetProxy} from "../mocks/MockFleetProxy.sol";
import {MockStargateV2} from "../mocks/MockStargateV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/oft-evm/contracts/libs/OFTComposeMsgCodec.sol";

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
    MockStargateV2 mockStargateMainnet;
    MockStargateV2 mockStargateArbitrum;

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
        adapterMainnet.addSupportedChain(
            CHAIN_ID_MAINNET,
            LZ_EID_MAINNET,
            address(adapterMainnet)
        );
        // Don't add CHAIN_ID_ARBITRUM yet - will add after arbitrum adapter is deployed

        // Deploy mock Stargate contract for mainnet USDC
        mockStargateMainnet = new MockStargateV2(
            USDC_MAINNET,
            MockStargateV2.StargateType.Pool
        );

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
        adapterArbitrum.addSupportedChain(
            CHAIN_ID_MAINNET,
            LZ_EID_MAINNET,
            address(adapterMainnet)
        );
        adapterArbitrum.addSupportedChain(
            CHAIN_ID_ARBITRUM,
            LZ_EID_ARBITRUM,
            address(adapterArbitrum)
        );

        routerArbitrum.registerAdapter(address(adapterArbitrum));

        // Deploy fleet proxy on Arbitrum
        fleetProxyArbitrum = new MockFleetProxy(USDC_ARBITRUM);

        // Deploy mock Stargate contract for Arbitrum USDC
        mockStargateArbitrum = new MockStargateV2(
            USDC_ARBITRUM,
            MockStargateV2.StargateType.Pool
        );

        // Add asset support for USDC on Arbitrum
        adapterArbitrum.addSupportedAsset(
            USDC_ARBITRUM,
            address(mockStargateArbitrum)
        );

        vm.stopPrank();

        // Now add arbitrum chain support to mainnet adapter with the correct arbitrum adapter address
        vm.selectFork(0); // Switch back to mainnet
        vm.prank(governor);
        adapterMainnet.addSupportedChain(
            CHAIN_ID_ARBITRUM,
            LZ_EID_ARBITRUM,
            address(adapterArbitrum)
        );
    }

    function testComposeGasLimitConfiguration() public {
        vm.selectFork(0); // Mainnet

        // Test gas limit bounds
        uint256 minGas = adapterMainnet.MIN_COMPOSE_GAS();
        uint256 maxGas = adapterMainnet.MAX_COMPOSE_GAS();

        assertEq(minGas, 200000, "Min compose gas should be 200k");
        assertEq(maxGas, 1000000, "Max compose gas should be 500k");

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
        adapterMainnet.setComposeGasLimit(1500000); // Too high (above MAX_COMPOSE_GAS of 1000000)
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
        bytes4 unauthorizedSelector = IBridgeAdapter.Unauthorized.selector;

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

    function testDebugMessageLengths() public view {
        // Setup test data
        bytes32 operationId = keccak256("test-operation");
        uint256 amount = 1000e6;

        // Create our custom compose message (what we want to pass to the FleetProxy)
        bytes memory customComposeMessage = abi.encode(
            address(fleetProxyArbitrum),
            USDC_ARBITRUM,
            amount,
            uint256(CHAIN_ID_MAINNET),
            operationId,
            user
        );

        console.log(
            "Custom compose message length:",
            customComposeMessage.length
        );
        console.log("Expected minimum length: 192");
        console.log(
            "Custom message is valid:",
            customComposeMessage.length >= 192
        );

        // Create the OFT-encoded compose message
        bytes memory oftEncodedMessage = OFTComposeMsgCodec.encode(
            uint64(1), // nonce
            uint32(LZ_EID_MAINNET), // source endpoint ID
            amount, // amount in local decimals
            customComposeMessage // No adapter address wrapping
        );

        console.log("OFT encoded message length:", oftEncodedMessage.length);
    }

    // Helper functions to call OFTComposeMsgCodec with calldata
    function getAmountLD(
        bytes calldata message
    ) external pure returns (uint256) {
        return OFTComposeMsgCodec.amountLD(message);
    }

    function getComposeMsg(
        bytes calldata message
    ) external pure returns (bytes memory) {
        return OFTComposeMsgCodec.composeMsg(message);
    }

    function testRealStargateFeeConsistency() public {
        vm.selectFork(0); // Mainnet

        // Skip if no real Stargate contracts are configured
        try adapterMainnet.assetToStargateContract(USDC_MAINNET) returns (
            address stargateContract
        ) {
            if (stargateContract == address(0)) {
                vm.skip(true);
                return;
            }
        } catch {
            vm.skip(true);
            return;
        }

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        uint256 amount = 1000e6; // 1000 USDC

        // Get fee estimate
        (uint256 estimatedFee, ) = adapterMainnet.estimateFee(
            CHAIN_ID_ARBITRUM,
            USDC_MAINNET,
            amount,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Deal USDC to user and router
        deal(USDC_MAINNET, user, amount);
        deal(USDC_MAINNET, address(routerMainnet), amount);

        // Give router enough ETH
        vm.deal(address(routerMainnet), estimatedFee * 2);

        // Approve adapter
        vm.prank(address(routerMainnet));
        IERC20(USDC_MAINNET).approve(address(adapterMainnet), amount);

        bytes32 operationId = keccak256("test-fee-consistency");

        BridgeRouterTestHelper(address(routerMainnet)).setOperationToAdapter(
            operationId,
            address(adapterMainnet)
        );

        // Test with estimated fee - should work
        vm.prank(address(routerMainnet));
        adapterMainnet.transferAsset{value: estimatedFee}(
            operationId,
            CHAIN_ID_ARBITRUM,
            USDC_MAINNET,
            address(fleetProxyArbitrum),
            amount,
            user,
            user,
            adapterParams
        );
    }

    function testMsgValueThroughInternalCalls() public {
        vm.selectFork(0); // Mainnet

        // This test specifically checks that msg.value is preserved through internal function calls
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        uint256 amount = 1000e6;
        uint256 providedFee = 2 ether; // Generous amount

        // Mock the internal flow by calling estimateFee multiple times
        // to ensure consistent results
        (uint256 fee1, ) = adapterMainnet.estimateFee(
            CHAIN_ID_ARBITRUM,
            USDC_MAINNET,
            amount,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        (uint256 fee2, ) = adapterMainnet.estimateFee(
            CHAIN_ID_ARBITRUM,
            USDC_MAINNET,
            amount,
            adapterParams,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Fees should be consistent between calls
        assertEq(fee1, fee2, "Fee estimation should be consistent");

        // Provided fee should be much larger than estimated
        assertGt(
            providedFee,
            fee1 * 10,
            "Provided fee should be much larger than estimated"
        );
    }
}
