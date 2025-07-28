// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {LayerZeroAdapter} from "../../src/adapters/LayerZeroAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {EVMCallRequestV1, ReadCodecV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {console} from "forge-std/Test.sol";

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
 * @dev Fork test to verify LayerZero layerZeroAdapter state read functionality on Base mainnet
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
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, uint256 tokenFee) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            options,
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
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Ensure we have enough ETH
        assertGe(
            address(keeper).balance,
            nativeFee,
            "Insufficient balance for operation"
        );

        // Set up the operation-to-layerZeroAdapter mapping for testing
        router.setOperationToAdapter(
            currentOperationId,
            address(layerZeroAdapter)
        );

        // Set bridge router as the sender to bypass access control
        vm.startPrank(address(router));

        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.readState{value: nativeFee}(
            currentOperationId,
            params,
            options
        );
        vm.stopPrank();
    }

    function testReadStateWithInsufficientFee() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_insufficient", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Try to send with insufficient fee from bridge router
        vm.startPrank(address(router));
        vm.expectRevert(); // Should revert due to insufficient fee
        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.readState{value: nativeFee / 2}(
            currentOperationId,
            params,
            options
        );
        vm.stopPrank();
    }

    function testReadStateUnauthorizedCaller() public {
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_unauthorized", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Try to call readState directly (not through bridge router)
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OnlyBridgeRouter()"));
        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.readState{value: 1 ether}(
            currentOperationId,
            params,
            options
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
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: customGasLimit,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Set up the operation-to-layerZeroAdapter mapping for testing
        router.setOperationToAdapter(
            currentOperationId,
            address(layerZeroAdapter)
        );

        vm.startPrank(address(router));
        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.readState{value: nativeFee}(
            currentOperationId,
            params,
            options
        );
        vm.stopPrank();

        // Test passes if no revert occurs - actual LZ transaction would complete on real network
    }

    function testReadChannelNotConfigured() public {
        // Deploy new layerZeroAdapter without read channel configuration
        LayerZeroAdapter unconfiguredAdapter = _deployUnconfiguredAdapter();

        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_operation_no_channel", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(unconfiguredAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Should revert with ReadChannelNotConfigured error
        vm.startPrank(address(router));
        vm.expectRevert(abi.encodeWithSignature("ReadChannelNotConfigured()"));

        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        unconfiguredAdapter.readState{value: 1 ether}(
            currentOperationId,
            params,
            options
        );
        vm.stopPrank();
    }

    function testGetRequiredFeeFunction() public view {
        // Create target call data
        bytes memory targetCallData = abi.encodePacked(
            MockTargetContract.getTestValue.selector,
            ""
        );

        // Create EVMCallRequestV1 array exactly like the layerZeroAdapter does
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

        // Encode using ReadCodecV1.encode exactly like the layerZeroAdapter does
        bytes memory payload = ReadCodecV1.encode(0, readRequests);

        uint256 requiredFee = layerZeroAdapter.getRequiredFee(
            READ_CHANNEL_ID, // Use read channel ID for state reads
            BridgeTypes.OperationType.READ_STATE,
            payload
        );

        assertGt(requiredFee, 0, "Required fee should be greater than 0");
        console.log("Required fee for state read:", requiredFee);
    }

    function testLayerZeroEndpointIntegration() public {
        // Test that the layerZeroAdapter can successfully interact with the real LayerZero endpoint
        bytes32 currentOperationId = keccak256(
            abi.encodePacked("test_lz_integration", block.timestamp)
        );

        bytes4 selector = MockTargetContract.getTestValue.selector;
        bytes memory readParams = "";

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Set up the operation-to-layerZeroAdapter mapping for testing
        router.setOperationToAdapter(
            currentOperationId,
            address(layerZeroAdapter)
        );

        // This test verifies that the real LayerZero endpoint accepts our read request
        // Even though we can't complete the cross-chain flow in a fork test,
        // we can verify the transaction doesn't revert when submitted to the endpoint
        vm.startPrank(address(router));
        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        // The transaction should not revert if properly configured
        try
            layerZeroAdapter.readState{value: nativeFee}(
                currentOperationId,
                params,
                options
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

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 300000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(targetContract),
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Verify that the layerZeroAdapter's read channel configuration is correct
        assertEq(
            layerZeroAdapter.readChannelId(),
            READ_CHANNEL_ID,
            "Read channel not properly configured"
        );

        // Set up the operation-to-layerZeroAdapter mapping for testing
        router.setOperationToAdapter(
            currentOperationId,
            address(layerZeroAdapter)
        );

        // Execute read state to verify ReadLib configuration
        vm.startPrank(address(router));

        // This should not revert if ReadLib1002 is properly configured
        BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
            .ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(targetContract),
                selector: selector,
                readParams: readParams,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.readState{value: nativeFee}(
            currentOperationId,
            params,
            options
        );

        vm.stopPrank();

        console.log(
            "ReadLib1002 configuration appears to be working correctly"
        );
    }
}
