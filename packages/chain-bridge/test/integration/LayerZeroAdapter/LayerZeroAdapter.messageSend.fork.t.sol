// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
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

    function testSendMessageViaQueue() public {
        console.log("=== Testing Core Message Send Via Queue ===");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        bytes memory message = abi.encode("Hello Cross-Chain!");

        // Get quote for fees
        (uint256 nativeFee, , ) = router.quoteSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(0x1234), // Target contract
                message: message,
                originator: keeper,
                refundAddress: keeper
            }),
            options
        );

        // 2. Execute the operation
        // Provide sufficient value for both fee and forwarding (msgValue = 0 in this case)
        vm.startPrank(keeper);

        router.executeSendMessage{
            value: nativeFee + options.msgValue + 2 ether
        }(
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
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        (uint256 nativeFee, ) = layerZeroAdapter.estimateSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: address(0x1234), // Target contract
                message: message,
                originator: address(this),
                refundAddress: address(this)
            }),
            options
        );

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
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
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
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        (uint256 nativeFee, uint256 tokenFee) = layerZeroAdapter
            .estimateSendMessage(
                BridgeTypes.ExecuteSendMessageParams({
                    destinationChainId: DEST_CHAIN_ID,
                    target: address(0x1234), // Target contract
                    message: abi.encode("Fee estimation test"),
                    originator: address(this),
                    refundAddress: address(this)
                }),
                options
            );

        assertGt(nativeFee, 0, "Native fee should be greater than 0");
        assertEq(tokenFee, 0, "Token fee should be 0 for LayerZero");

        console.log("Estimated fee:", nativeFee);
        console.log("[SUCCESS] Fee estimation working correctly");
    }

    function testSendMessageWithProtocolTokenAndMsgValueSkipped() public {
        console.log("=== Testing Protocol Token Payment with msgValue ===");
        console.log("Skipping test: LZ Token Payment is not available yet");
        return; // Skipping test until LZ Token Payment is available

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.2 ether, // Forward 0.5 ETH to destination
            options: "",
            payInProtocolToken: true,
            feeTokenAmount: PROTOCOL_FEE_AMOUNT
        });

        bytes memory message = abi.encode(
            "Hello Cross-Chain with Protocol Token Payment!"
        );

        // Record initial balances
        uint256 initialKeeperBalance = keeper.balance;
        uint256 initialProtocolTokenBalance = protocolFeeToken.balanceOf(
            keeper
        );

        // Get quote for fees
        (uint256 nativeFee, , ) = router.quoteSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: message,
                originator: keeper,
                refundAddress: keeper
            }),
            options
        );

        console.log("Native fee:", nativeFee);
        console.log("Msg value:", options.msgValue);
        console.log("Protocol fee amount:", PROTOCOL_FEE_AMOUNT);

        // Execute the operation with protocol token payment
        vm.startPrank(keeper);
        router.executeSendMessage{value: 3 ether}(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user,
                message: message,
                originator: keeper,
                refundAddress: keeper
            }),
            options
        );
        vm.stopPrank();

        // Verify protocol tokens were spent
        uint256 finalProtocolTokenBalance = protocolFeeToken.balanceOf(keeper);
        assertEq(
            finalProtocolTokenBalance,
            initialProtocolTokenBalance - PROTOCOL_FEE_AMOUNT,
            "Protocol tokens should have been spent"
        );

        // Verify some native ETH was used (LayerZero fee + msgValue)
        uint256 finalKeeperBalance = keeper.balance;
        assertLt(
            finalKeeperBalance,
            initialKeeperBalance,
            "Some native ETH should have been used"
        );

        // Verify that the amount used is reasonable (should be less than 3 ETH)
        uint256 ethUsed = initialKeeperBalance - finalKeeperBalance;
        assertLt(ethUsed, 3 ether, "Should not use all 3 ETH");
        assertGt(ethUsed, 0.5 ether, "Should use at least the msgValue amount");

        console.log("ETH used:", ethUsed);
        console.log("Protocol tokens spent:", PROTOCOL_FEE_AMOUNT);
        console.log("[SUCCESS] Protocol token payment with msgValue completed");
    }

    function testEstimateSendMessageWithProtocolTokenFork() public view {
        console.log("=== Testing Protocol Token Fee Estimation on Fork ===");

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(layerZeroAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0.5 ether,
            options: "",
            payInProtocolToken: true,
            feeTokenAmount: PROTOCOL_FEE_AMOUNT
        });

        // Call estimateSendMessage with protocol token payment
        (uint256 nativeFee, uint256 tokenFee) = layerZeroAdapter
            .estimateSendMessage(
                BridgeTypes.ExecuteSendMessageParams({
                    destinationChainId: DEST_CHAIN_ID,
                    target: user,
                    message: abi.encode("Protocol token estimation test"),
                    originator: keeper,
                    refundAddress: keeper
                }),
                options
            );

        // When paying in protocol tokens, native fee should be 0
        assertEq(
            nativeFee,
            0,
            "Native fee should be 0 when paying in protocol tokens"
        );
        assertGt(tokenFee, 0, "Token fee should be greater than 0");

        console.log("Native fee:", nativeFee);
        console.log("Token fee:", tokenFee);
        console.log("[SUCCESS] Protocol token fee estimation working on fork");
    }
}
