// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICallValidationRegistry} from "../../interfaces/intents/ICallValidationRegistry.sol";

/**
 * @title ValidatedCallerBase
 * @notice Base contract that provides validated arbitrary call execution via a registry.
 * @dev Intended to be inherited by contracts that need to perform arbitrary calls
 *      gated by an external validator/registry (e.g. Arks, managers).
 */
abstract contract ValidatedCallerBase {
    /// @notice Registry used to validate arbitrary calls initiated by this contract
    ICallValidationRegistry public immutable validationRegistry;

    /// @notice Emitted after a successful arbitrary call
    event CallExecuted(address indexed target, bytes returnData);

    /// @notice Thrown when validation registry address is zero
    error InvalidValidationRegistry();
    /// @notice Thrown when the external call target is the zero address
    error InvalidTarget();
    /// @notice Thrown when the registry/validator rejects a call
    error CallNotAllowed(address target);
    /// @notice Thrown when the low-level call fails
    error ExternalCallFailed(address target, bytes returnData);

    /**
     * @param _validationRegistry Address of the call validation registry
     */
    constructor(address _validationRegistry) {
        if (_validationRegistry == address(0)) {
            revert InvalidValidationRegistry();
        }
        validationRegistry = ICallValidationRegistry(_validationRegistry);
    }

    /**
     * @notice Internal helper to perform a validated low-level call.
     * @dev Child contracts should expose this via an access-controlled external function.
     * @param target The target address to call
     * @param data The calldata for the call
     * @return result The raw returned data from the call
     */
    function _executeValidatedCall(
        address target,
        bytes calldata data
    ) internal returns (bytes memory result) {
        if (target == address(0)) {
            revert InvalidTarget();
        }

        // Validate via registry (can be stubbed to always return true)
        bool isValid = validationRegistry.validate(address(this), target, data);
        if (!isValid) {
            revert CallNotAllowed(target);
        }

        (bool success, bytes memory returnData) = target.call(data);
        if (!success) {
            revert ExternalCallFailed(target, returnData);
        }

        emit CallExecuted(target, returnData);
        return returnData;
    }
}
