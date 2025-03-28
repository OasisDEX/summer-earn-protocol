// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

contract LayerZeroIntegrationTest is Test {
    // Contracts
    BridgeRouter public router;
    LayerZeroAdapter public adapter;
    ProtocolAccessManager public accessManager;

    // Addresses
    address public governor = address(0x1);
    address public guardian = address(0x2);
    address public user = address(0x3);
    address public recipient = address(0x4);

    uint16 public constant DEST_CHAIN_ID = 42161; // Arbitrum
    uint32 public constant ARB_LZ_EID = 30110; // Correct LZ v2 EID for Arbitrum One

    // LZ specific config
    address public constant LZ_ENDPOINT_MAINNET =
        0x1a44076050125825900e736c501f859c50fE728c; // LZ v3 endpoint on mainnet

    // Test setup
    uint256 public constant NATIVE_AMOUNT = 1 ether;

    uint256 public constant FORK_BLOCK = 22_145_762;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), FORK_BLOCK);
        // Create access manager
        accessManager = new ProtocolAccessManager(governor);

        // Configure roles
        vm.startPrank(governor);
        accessManager.grantGuardianRole(guardian);
        vm.stopPrank();

        // Initialize chain router mappings
        uint16[] memory chainIds = new uint16[](1);
        address[] memory routerAddresses = new address[](1);
        chainIds[0] = DEST_CHAIN_ID;
        routerAddresses[0] = address(0x999); // Mock remote router address

        // Create contracts
        router = new BridgeRouter(
            address(accessManager),
            chainIds,
            routerAddresses
        );

        // Setup LZ adapter with v3 endpoint
        uint16[] memory supportedChains = new uint16[](1);
        uint32[] memory lzEids = new uint32[](1);
        supportedChains[0] = DEST_CHAIN_ID;
        lzEids[0] = ARB_LZ_EID; // Use the constant instead of hardcoded value

        adapter = new LayerZeroAdapter(
            LZ_ENDPOINT_MAINNET,
            address(router),
            supportedChains,
            lzEids,
            governor
        );

        // Register adapter with router
        vm.startPrank(governor);
        router.registerAdapter(address(adapter));

        // Set up peer for Arbitrum chain
        bytes32 peerAddressBytes32 = bytes32(uint256(uint160(address(0x999))));
        adapter.setPeer(ARB_LZ_EID, peerAddressBytes32);

        // Activate the read channel for state reading operations
        uint32 READ_CHANNEL_ID = 4294967295;
        // https://docs.layerzero.network/v2/deployments/read-contracts
        adapter.activateReadChannel(READ_CHANNEL_ID);

        // Configure ReadLib1002 for lzRead functionality
        address READ_LIB_1002 = 0x74F55Bc2a79A27A0bF1D1A35dB5d0Fc36b9FDB9D;

        // Since governor is the OApp owner, we need to call the endpoint directly to set libraries
        // This assumes we're working with ILayerZeroEndpointV2 interface
        address lzEndpoint = LZ_ENDPOINT_MAINNET;

        // Set send and receive libraries on the endpoint for our adapter (OApp)
        // Note: We're mocking these calls since actual implementation would require properly formatted interfaces
        (bool success, ) = lzEndpoint.call(
            abi.encodeWithSignature(
                "setSendLibrary(address,uint32,address)",
                address(adapter), // OApp address
                READ_CHANNEL_ID, // Read channel ID
                READ_LIB_1002 // new library
            )
        );
        require(success, "setSendLibrary failed");

        (success, ) = lzEndpoint.call(
            abi.encodeWithSignature(
                "setReceiveLibrary(address,uint32,address,uint256)",
                address(adapter), // OApp address
                READ_CHANNEL_ID, // Read channel ID
                READ_LIB_1002, // new library
                0
            )
        );
        require(success, "setReceiveLibrary failed");

        // Configure read channel ID (assuming adapter has this capability)
        adapter.setReadChannel(READ_CHANNEL_ID, true);

        vm.stopPrank();

        // Fund user with ETH
        vm.deal(user, NATIVE_AMOUNT);
    }

    function testSendMessageViaLayerZero() public {
        vm.startPrank(user);

        // Create adapter params
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(adapter),
            adapterParams: adapterParams
        });

        // Get quote for fees
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0), // No asset for general message
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Create a test message
        bytes memory message = abi.encode("Hello, Cross-Chain World!");

        // Send the message through the router
        bytes32 operationId = router.sendMessage{value: nativeFee}(
            DEST_CHAIN_ID,
            recipient,
            message,
            options
        );

        // Verify the message was properly registered
        assertEq(
            uint256(router.getOperationStatus(operationId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );

        // Verify adapter was assigned to this operation
        assertEq(router.operationToAdapter(operationId), address(adapter));

        vm.stopPrank();
    }

    function testReadStateViaLayerZero() public {
        vm.startPrank(user);

        // Create adapter params with increased calldataSize for read operations
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                calldataSize: 100, // Expected return data size
                msgValue: 0,
                options: "" // Remove any custom options, let adapter handle it correctly
            });

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0),
            adapterParams: adapterParams
        });

        // Get quote for fees
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0), // No asset for state read
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Define parameters for the state read
        bytes4 selector = bytes4(keccak256("balanceOf(address)"));
        bytes memory callData = abi.encode(user);

        bytes32 operationId = router.readState{value: nativeFee}(
            DEST_CHAIN_ID,
            recipient,
            selector,
            callData,
            options
        );

        // Verify the operation was properly registered
        assertEq(
            uint256(router.getOperationStatus(operationId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );

        // Verify adapter was assigned to this operation
        assertEq(router.operationToAdapter(operationId), address(adapter));

        vm.stopPrank();
    }

    // Test confirmation mechanism
    function testConfirmationMessageStructure() public pure {
        bytes memory message = abi.encode(
            bytes32(uint256(0x1234567890)), // Example operation ID
            BridgeTypes.OperationStatus.COMPLETED
        );

        // Extract the status value as it would be done in _isConfirmationMessage
        uint256 statusValue;
        assembly {
            statusValue := mload(add(add(message, 32), 32))
        }

        // Verify the extracted value matches OperationStatus.COMPLETED
        assertEq(statusValue, uint256(BridgeTypes.OperationStatus.COMPLETED));
    }
}
