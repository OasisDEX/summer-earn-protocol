// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {LayerZeroAdapterForkSetupTest} from "./LayerZeroAdapter.fork.setup.t.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title LayerZero Message Send Fork Test
 * @dev Core tests for LayerZero layerZeroAdapter message sending functionality
 */
contract LayerZeroAdapterMessageSendForkTest is LayerZeroAdapterForkSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function testAdapterConfiguration() public view {
        _verifyAdapterConfiguration();
    }

    function testSendMessageViaQueue() public {
        console.log("=== Testing Core Message Send Via Queue ===");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Get quote for fees
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        bytes memory message = abi.encode("Hello Cross-Chain!");

        // 2. Execute the operation
        vm.startPrank(keeper);

        bytes32 operationId = router.executeSendMessage{value: nativeFee}(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: message,
                originator: keeper,
                refundAddress: address(keeper)
            }),
            options
        );
        vm.stopPrank();
    }

    function testSendMessageDirectViaAdapter() public {
        console.log("=== Testing Direct Adapter Call ===");

        bytes32 operationId = keccak256("test_direct_message");
        bytes memory message = abi.encode("Direct message test");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Set up operation mapping
        router.setOperationToAdapter(operationId, address(layerZeroAdapter));

        // Call layerZeroAdapter through router context (authorized)
        vm.startPrank(address(router));
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: keeper,
                message: message,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.sendMessage{value: nativeFee}(
            operationId,
            params,
            options
        );
        vm.stopPrank();

        console.log("[SUCCESS] Direct layerZeroAdapter call completed");
    }

    function testUnauthorizedAdapterCall() public {
        console.log("=== Testing Unauthorized Call Protection ===");

        bytes32 operationId = keccak256("unauthorized_test");
        bytes memory message = abi.encode("Unauthorized test");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        // Direct call should fail (not from router)
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSignature("OnlyBridgeRouter()"));
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: keeper,
                message: message,
                originator: keeper,
                refundAddress: address(keeper)
            });
        layerZeroAdapter.sendMessage{value: 1 ether}(
            operationId,
            params,
            options
        );
        vm.stopPrank();

        console.log("[SUCCESS] Authorization properly enforced");
    }

    function testEstimateMessageFee() public view {
        console.log("=== Testing Fee Estimation ===");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });

        (uint256 nativeFee, uint256 tokenFee) = layerZeroAdapter.estimateFee(
            DEST_CHAIN_ID,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
        );

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for LayerZero");

        console.log("Estimated fee:", nativeFee);
        console.log("[SUCCESS] Fee estimation working correctly");
    }
}
