// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SuperchainAdapterSetupTest} from "./SuperchainAdapter.setup.t.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../../src/interfaces/IBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {BridgeMessagingHelper} from "../../../src/libraries/BridgeMessagingHelper.sol";

contract SuperchainAdapterRelayTest is SuperchainAdapterSetupTest {
    function testRelayMessage_SuccessfulRelay() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 transferAmount = 1000e18;

        // Create relayed transfer parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: "test message"
            });

        // Encode the message
        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Set up cross-domain context
        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Mint tokens to adapter (simulating tokens received from Superchain bridge)
        tokenB.mint(address(adapterB), transferAmount);

        // Expect router.deliver to be called
        vm.expectCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, message)
            )
        );

        // Execute relay
        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(message);

        // Verify tokens were transferred to router
        assertEq(tokenB.balanceOf(address(routerB)), transferAmount);
        assertEq(tokenB.balanceOf(address(adapterB)), 0);
    }

    function testRelayMessage_RevertWhenUnauthorizedCaller() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 transferAmount = 1000e18;

        // Create relayed transfer parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: "test message"
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Call from unauthorized address (not L2ToL2Messenger)
        vm.prank(user);
        vm.expectRevert(IBaseBridgeAdapterErrors.Unauthorized.selector);
        adapterB.relayMessage(message);
    }

    function testRelayMessage_RevertWhenUntrustedSource() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 transferAmount = 1000e18;
        address untrustedSource = address(0x999);

        // Create relayed transfer parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: untrustedSource,
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: "test message"
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Set up cross-domain context with untrusted source
        l2ToL2MessengerB.setCrossDomainMessageSender(untrustedSource);
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Should revert when source is not trusted
        vm.prank(address(l2ToL2MessengerB));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.UntrustedSourceAdapter.selector,
                untrustedSource,
                CHAIN_ID_A
            )
        );
        adapterB.relayMessage(message);
    }

    function testRelayMessage_RevertWhenInvalidSourceChain() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 transferAmount = 1000e18;

        // Create relayed transfer parameters with mismatched source chain
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: 9999, // Wrong source chain
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: "test message"
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Set up cross-domain context
        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Should revert when source chain doesn't match
        vm.prank(address(l2ToL2MessengerB));
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidSourceChainId.selector
            )
        );
        adapterB.relayMessage(message);
    }

    function testRelayMessage_RevertWhenUnsupportedAsset() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 transferAmount = 1000e18;
        address unsupportedAsset = address(0x888);

        // Create relayed transfer parameters with unsupported asset
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: unsupportedAsset,
                amount: transferAmount,
                message: "test message"
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Set up cross-domain context
        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Should revert when asset is not supported
        vm.prank(address(l2ToL2MessengerB));
        vm.expectRevert(
            abi.encodeWithSelector(IBaseBridgeAdapterErrors.UnsupportedAsset.selector)
        );
        adapterB.relayMessage(message);
    }

    function testRelayMessage_RevertWhenZeroAmount() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");

        // Create relayed transfer parameters with zero amount
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: 0, // Zero amount
                message: "test message"
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Set up cross-domain context
        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Should revert when amount is zero
        vm.prank(address(l2ToL2MessengerB));
        vm.expectRevert(IBaseBridgeAdapterErrors.InvalidAmount.selector);
        adapterB.relayMessage(message);
    }

    function testRelayMessage_VerifyMessageDecoding() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 transferAmount = 1000e18;
        bytes memory testMessage = "test message content";

        // Create relayed transfer parameters
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: testMessage
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        // Set up cross-domain context
        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        // Mint tokens to adapter
        tokenB.mint(address(adapterB), transferAmount);

        // Expect router.deliver to be called
        vm.expectCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, message)
            )
        );

        // Execute relay
        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(message);
    }

    function testRelayMessage_MultipleRelays() public {
        useChainB();

        bytes32 operationId1 = keccak256("test-operation-1");
        bytes32 operationId2 = keccak256("test-operation-2");
        uint256 transferAmount = 1000e18;

        // First relay
        BridgeTypes.RelayedTransferParams memory params1 = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId1,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: "first message"
            });

        bytes memory message1 = BridgeMessagingHelper
            .encodeRelayedTransferParams(params1);

        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        tokenB.mint(address(adapterB), transferAmount);

        vm.mockCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, message1)
            ),
            abi.encode()
        );

        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(message1);

        // Second relay
        BridgeTypes.RelayedTransferParams memory params2 = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId2,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: transferAmount,
                message: "second message"
            });

        bytes memory message2 = BridgeMessagingHelper
            .encodeRelayedTransferParams(params2);

        tokenB.mint(address(adapterB), transferAmount);

        vm.mockCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, message2)
            ),
            abi.encode()
        );

        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(message2);

        // Verify both relays completed
        assertEq(tokenB.balanceOf(address(routerB)), transferAmount * 2);
        assertEq(tokenB.balanceOf(address(adapterB)), 0);
    }

    function testRelayMessage_LargeAmount() public {
        useChainB();

        bytes32 operationId = keccak256("test-operation");
        uint256 largeAmount = 1000000e18; // 1M tokens

        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                originator: address(adapterA),
                sourceChainId: CHAIN_ID_A,
                recipient: recipient,
                asset: address(tokenB),
                amount: largeAmount,
                message: "large transfer"
            });

        bytes memory message = BridgeMessagingHelper
            .encodeRelayedTransferParams(params);

        l2ToL2MessengerB.setCrossDomainMessageSender(address(adapterA));
        l2ToL2MessengerB.setCrossDomainMessageSource(CHAIN_ID_A);

        tokenB.mint(address(adapterB), largeAmount);

        vm.mockCall(
            address(routerB),
            abi.encodeCall(
                IBridgeRouter.deliver,
                (BridgeTypes.OperationType.TRANSFER_ASSET, message)
            ),
            abi.encode()
        );

        vm.prank(address(l2ToL2MessengerB));
        adapterB.relayMessage(message);

        // Verify large transfer completed
        assertEq(tokenB.balanceOf(address(routerB)), largeAmount);
        assertEq(tokenB.balanceOf(address(adapterB)), 0);
    }
}
