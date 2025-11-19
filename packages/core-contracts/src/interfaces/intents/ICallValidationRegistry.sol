// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICallValidator} from "./ICallValidator.sol";

/**
 * @title ICallValidationRegistry
 * @notice Registry that resolves validators used to validate arbitrary calls
 */
interface ICallValidationRegistry {
    /**
     * @notice Returns the validator to use for a given caller
     * @param caller The address initiating the call (e.g. an Ark)
     * @return validator The validator contract to use
     */
    function validatorFor(
        address caller
    ) external view returns (ICallValidator validator);

    /**
     * @notice Convenience function to validate a call through the registry
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
