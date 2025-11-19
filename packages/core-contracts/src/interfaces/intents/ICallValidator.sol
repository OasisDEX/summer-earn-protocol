// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICallValidator
 * @notice Interface for validating arbitrary calls initiated by an Ark
 */
interface ICallValidator {
    /**
     * @notice Validate a low-level call
     * @param caller The address initiating the call (e.g. an Ark)
     * @param target The target address of the call
     * @param data The calldata for the call
     * @return isValid True if the call is considered valid
     */
    function validate(
        address caller,
        address target,
        bytes calldata data
    ) external view returns (bool isValid);
}
