// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICallValidator} from "../../interfaces/intents/ICallValidator.sol";

/**
 * @title CallValidator
 * @notice Mock implementation of `ICallValidator` that always approves calls.
 * @dev This is a temporary stub and MUST be replaced with a real validator before production.
 */
contract CallValidator is ICallValidator {
    /// @inheritdoc ICallValidator
    function validate(
        address,
        address,
        bytes calldata
    ) external pure override returns (bool isValid) {
        // Always returns true as a mock
        return true;
    }
}
