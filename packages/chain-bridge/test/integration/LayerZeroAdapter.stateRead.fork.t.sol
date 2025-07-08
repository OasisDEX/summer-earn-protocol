// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/Test.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ReadCodecV1, EVMCallRequestV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";

// Mock target contract on destination chain for state reading
contract MockTargetContract {
    uint256 public testValue = 12345;
    address public testAddress =
        address(0x1234567890123456789012345678901234567890);

    function getTestValue() external view returns (uint256) {
        return testValue;
    }

    function getTestAddress() external view returns (address) {
        return testAddress;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1000e18; // Mock balance
    }
    function testSkipper() public {}
}

/**
 * @title LayerZeroAdapter State Read Fork Test (Base)
 * @dev Fork test to verify LayerZero adapter state read functionality on Base mainnet
 */
contract LayerZeroAdapterStateReadBaseForkTest is
    LayerZeroAdapterForkSetupTest
{
    MockTargetContract public targetContract;

    function setUp() public override {
        super.setUp();

        // Deploy mock target contract (simulates destination chain contract)
        targetContract = new MockTargetContract();
    }

    function testAdapterConfiguration() public view {
        _verifyAdapterConfiguration();
    }

    function testEstimateStateReadFee() public view {
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, uint256 tokenFee) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for LayerZero");

        console.log("Estimated state read fee:", nativeFee);
    }

    function testReadStateExecution() public {
        // Generate operation ID
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation", block.timestamp)
        );

        // Define read parameters
        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        // Get fee estimate
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Ensure we have enough ETH
        assertGe(
            address(keeper).balance,
            nativeFee,
            "Insufficient balance for operation"
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        // Set bridge router as the sender to bypass access control
        vm.startPrank(address(router));

        adapter.readState{value: nativeFee}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadStateWithInsufficientFee() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_insufficient", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Try to send with insufficient fee from bridge router
        vm.startPrank(address(router));
        vm.expectRevert(); // Should revert due to insufficient fee
        adapter.readState{value: nativeFee / 2}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadStateUnauthorizedCaller() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_unauthorized", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Try to call readState directly (not through bridge router)
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        adapter.readState{value: 1 ether}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadStateWithCustomGasLimit() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_custom_gas", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        // Use higher gas limit than minimum
        uint64 customGasLimit = 300000 * 2;
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: customGasLimit,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        vm.startPrank(address(router));
        adapter.readState{value: nativeFee}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();

        // Test passes if no revert occurs - actual LZ transaction would complete on real network
    }

    function testUnsupportedChain() public {
        uint16 unsupportedChainId = 999;
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_unsupported", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Should revert with UnsupportedChain error
        vm.startPrank(address(router));
        vm.expectRevert(abi.encodeWithSignature("UnsupportedChain()"));
        adapter.readState{value: 1 ether}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            unsupportedChainId,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testReadChannelNotConfigured() public {
        // Deploy new adapter without read channel configuration
        LayerZeroAdapter unconfiguredAdapter = _deployUnconfiguredAdapter();

        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_no_channel", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        // Should revert with ReadChannelNotConfigured error
        vm.startPrank(address(router));
        vm.expectRevert(abi.encodeWithSignature("ReadChannelNotConfigured()"));
        unconfiguredAdapter.readState{value: 1 ether}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );
        vm.stopPrank();
    }

    function testGetRequiredFeeFunction() public view {
        // Create target call data
        bytes memory targetCallData = abi.encodePacked(
            MockTargetContract.getTestValue.selector,
            ""
        );

        // Create EVMCallRequestV1 array exactly like the adapter does
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](1);
        readRequests[0] = EVMCallRequestV1({
            appRequestLabel: 1,
            targetEid: ARB_LZ_EID,
            isBlockNum: false,
            blockNumOrTimestamp: uint64(block.timestamp),
            confirmations: 15,
            to: address(targetContract),
            callData: targetCallData
        });

        // Encode using ReadCodecV1.encode exactly like the adapter does
        bytes memory payload = ReadCodecV1.encode(0, readRequests);

        uint256 requiredFee = adapter.getRequiredFee(
            READ_CHANNEL_ID, // Use read channel ID for state reads
            adapter.STATE_READ(), // STATE_READ = 2
            payload
        );

        assertGt(requiredFee, 0, "Required fee should be greater than 0");
        console.log("Required fee for state read:", requiredFee);
    }

    function testLayerZeroEndpointIntegration() public {
        // Test that the adapter can successfully interact with the real LayerZero endpoint
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_lz_integration", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        // This test verifies that the real LayerZero endpoint accepts our read request
        // Even though we can't complete the cross-chain flow in a fork test,
        // we can verify the transaction doesn't revert when submitted to the endpoint
        vm.startPrank(address(router));

        // The transaction should not revert if properly configured
        try
            adapter.readState{value: nativeFee}(
                currentOperationId,
                SOURCE_CHAIN_ID,
                DEST_CHAIN_ID,
                address(targetContract),
                selector,
                readParams,
                keeper,
                adapterParams
            )
        {
            // Success - the read request was accepted by LayerZero endpoint
            console.log("LayerZero endpoint accepted the read request");
        } catch Error(string memory reason) {
            // If it reverts with a specific error, we can analyze it
            console.log("LayerZero endpoint rejected request:", reason);
            // Re-throw to fail the test if there's an unexpected error
            revert(reason);
        }

        vm.stopPrank();
    }

    function testReadLibraryConfiguration() public {
        // Test that ReadLib1002 is properly configured
        // We can verify this by checking that read operations don't revert
        // with library-related errors

        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_readlib_config", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 300000,
                msgValue: 0,
                calldataSize: 0,
                options: ""
            });

        (uint256 nativeFee, ) = adapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            adapterParams,
            BridgeTypes.OperationType.READ_STATE
        );

        // Verify that the adapter's read channel configuration is correct
        assertEq(
            adapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel not properly configured"
        );

        // Set up the operation-to-adapter mapping for testing
        router.setOperationToAdapter(currentOperationId, address(adapter));

        // Execute read state to verify ReadLib configuration
        vm.startPrank(address(router));

        // This should not revert if ReadLib1002 is properly configured
        adapter.readState{value: nativeFee}(
            currentOperationId,
            SOURCE_CHAIN_ID,
            DEST_CHAIN_ID,
            address(targetContract),
            selector,
            readParams,
            keeper,
            adapterParams
        );

        vm.stopPrank();

        console.log(
            "ReadLib1002 configuration appears to be working correctly"
        );
    }
}
