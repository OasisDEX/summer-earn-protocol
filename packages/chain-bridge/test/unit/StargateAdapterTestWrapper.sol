// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { StargateAdapter } from "../../src/adapters/StargateAdapter.sol";

/**
 * @title StargateAdapterTestWrapper
 * @notice Test wrapper that exposes internal methods for testing
 */
contract StargateAdapterTestWrapper is StargateAdapter {

    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint,
        address _harborCommand
    )
        StargateAdapter(_crossChainRegistry, _accessManager, _lzEndpoint, _harborCommand)
    { }

    /**
     * @notice Exposes the internal _isFleetProxy method for testing
     */
    function isFleetProxy(address recipient) external view returns (bool) {
        return _isFleetProxy(recipient);
    }

    /**
     * @notice Exposes the internal _validateFleetCommander method for testing
     */
    function validateFleetCommander(address fleetCommander) external view {
        _validateFleetCommander(fleetCommander);
    }

    /**
     * @notice Exposes the internal _handleComposedMessage method for testing
     */
    function handleComposedMessage(address _from, uint256 amountLD, bytes memory composeMsg) external {
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
    )
        external
    {
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

    /**
     * @notice Test function to call _handleUserLedFailure directly
     */
    function testHandleUserLedFailure(
        address asset,
        uint256 amount,
        address user,
        bytes32 operationId,
        address originalUser,
        uint16 sourceChainId
    )
        external
    {
        _handleUserInitiatedFailure(asset, amount, user, operationId, originalUser, sourceChainId);
    }

}
