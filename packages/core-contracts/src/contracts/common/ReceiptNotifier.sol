// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";

/**
 * @title ReceiptNotifier
 * @notice Shared helper for sending standardized cross-chain notifications with arbitrary payload
 * @dev Mixin to be inherited by contracts needing to send message-based notifications
 */
abstract contract ReceiptNotifier {
    function _notifierBridgeRouter() internal view virtual returns (address);
    /**
     * @notice Sends a notification message with arbitrary payload
     * @param destinationChainId Target chain id
     * @param target Recipient contract on destination chain
     * @param payload Encoded payload (can be empty for pure ACK)
     * @param options Bridge options
     * @param refundAddress Where to refund any unused value
     */
    function _sendNotification(
        uint16 destinationChainId,
        address target,
        bytes memory payload,
        BridgeTypes.BridgeOptions calldata options,
        address refundAddress
    ) internal {
        IBridgeRouter router = IBridgeRouter(_notifierBridgeRouter());
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                originator: address(this),
                destinationChainId: destinationChainId,
                target: target,
                message: payload,
                refundAddress: refundAddress
            });
        router.executeSendMessage{value: msg.value}(params, options);
        emit NotificationSent(keccak256(payload), destinationChainId, target);
    }
    event NotificationSent(
        bytes32 payloadHash,
        uint16 destinationChainId,
        address target
    );
}
