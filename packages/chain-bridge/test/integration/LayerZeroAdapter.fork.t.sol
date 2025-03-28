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
    uint32 public constant ARB_LZ_EID = 30184;

    // LZ specific config
    address public constant LZ_ENDPOINT_MAINNET =
        0x1a44076050125825900e736c501f859c50fE728c; // LZ v3 endpoint on mainnet

    // Test setup
    uint256 public constant NATIVE_AMOUNT = 1 ether;

    uint256 public constant FORK_BLOCK = 20_137_939;

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
        lzEids[0] = 30184; // LZ EID for Arbitrum

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

        // Set up peer for Arbitrum chain (this is what's missing)
        // Convert the router address to bytes32 format
        bytes32 peerAddressBytes32 = bytes32(uint256(uint160(address(0x999))));
        adapter.setPeer(30184, peerAddressBytes32);

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
            specifiedAdapter: address(adapter),
            adapterParams: adapterParams
        });

        // Get quote for fees with explicit operation type
        (uint256 nativeFee, , address selectedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(0), // No asset for read operation
            0,
            options,
            BridgeTypes.OperationType.READ_STATE // Specify operation type
        );

        // Define parameters for the state read
        bytes4 selector = bytes4(keccak256("balanceOf(address)"));
        bytes memory callData = abi.encode(user);

        bytes32 operationId = router.readState{value: (nativeFee * 11) / 10}(
            DEST_CHAIN_ID,
            recipient,
            selector,
            callData,
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(selectedAdapter), // Use the same adapter
                adapterParams: adapterParams
            })
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
