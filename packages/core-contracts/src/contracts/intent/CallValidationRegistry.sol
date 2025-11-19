// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICallValidator} from "../../interfaces/intents/ICallValidator.sol";
import {ICallValidationRegistry} from "../../interfaces/intents/ICallValidationRegistry.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
/**
 * @title CallValidationRegistry
 * @notice Mock implementation of `ICallValidationRegistry` that always approves calls.
 * @dev This is a temporary stub and MUST be replaced with a real registry/validation
 *      logic before production use.
 */
contract CallValidationRegistry is
    ICallValidationRegistry,
    ProtocolAccessManaged
{
    mapping(address => ICallValidator) public validators;
    error InvalidValidator(address caller);
    event ValidatorSet(address indexed caller, address indexed validator);
    event ValidatorRemoved(address indexed caller);
    /**
     * @notice Returns a dummy validator address.
     * @dev For now, this returns `address(0)` as the underlying validator is not used.
     */
    function validatorFor(
        address caller
    ) external view override returns (ICallValidator validator) {
        return validators[caller];
    }

    /// @inheritdoc ICallValidationRegistry
    function validate(
        address caller,
        address target,
        bytes calldata data
    ) external view override returns (bool isValid) {
        ICallValidator validator = validators[caller];
        if (address(validator) == address(0)) {
            revert InvalidValidator(caller);
        }
        return validators[caller].validate(caller, target, data);
    }

    function setValidator(
        address caller,
        ICallValidator validator
    ) external onlyGovernor {
        validators[caller] = validator;
        emit ValidatorSet(caller, address(validator));
    }

    function removeValidator(address caller) external onlyGovernor {
        delete validators[caller];
        emit ValidatorRemoved(caller);
    }

    constructor(address accessManager) ProtocolAccessManaged(accessManager) {}
}
