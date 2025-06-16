// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";

/**
 * @title StargateAdapterTestWrapper
 * @notice Test wrapper that exposes internal methods for testing
 */
contract StargateAdapterTestWrapper is StargateAdapter {
    constructor(
        address _bridgeRouter,
        address _owner,
        address _lzEndpoint
    ) StargateAdapter(_bridgeRouter, _owner, _lzEndpoint) {}

    /**
     * @notice Exposes the internal _isFleetProxy method for testing
     */
    function isFleetProxy(address recipient) external view returns (bool) {
        return _isFleetProxy(recipient);
    }

    /**
     * @notice Exposes the internal _handleComposedMessage method for testing
     */
    function handleComposedMessage(
        address _from,
        uint256 amountLD,
        bytes memory composeMsg
    ) external {
        _handleComposedMessage(_from, amountLD, composeMsg);
    }

    /**
     * @notice Manually add a failed compose for testing
     */
    function addTestFailedCompose(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        address originator,
        uint16 sourceChainId,
        bool isDeposit
    ) external {
        failedComposes[operationId] = FailedCompose({
            asset: asset,
            amount: amount,
            intendedRecipient: recipient,
            operationId: operationId,
            originator: originator,
            sourceChainId: sourceChainId,
            timestamp: block.timestamp,
            isDeposit: isDeposit
        });

        failedOperationIds.push(operationId);
    }
}
