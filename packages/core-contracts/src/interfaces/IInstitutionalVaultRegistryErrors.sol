// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IInstitutionalVaultRegistryErrors
 * @notice Custom errors for the Institutional Vault Registry
 */
interface IInstitutionalVaultRegistryErrors {
    /**
     * @notice Reverts when trying to add an institution that already exists
     */
    error InstitutionAlreadyExists(bytes32 id);

    /**
     * @notice Reverts when the specified institution cannot be found
     */
    error InstitutionNotFound(bytes32 id);

    /**
     * @notice Reverts when operating on an institution that has been disabled
     */
    error InstitutionIsDisabled(bytes32 id);

    /**
     * @notice Reverts when a provided address is zero
     */
    error AddressZero();

    /**
     * @notice Reverts when attempting to update an immutable field for an institution
     * @dev field is the keccak256("fieldName") for clarity on-chain
     */
    error ImmutableFieldUpdateForbidden(bytes32 id, bytes32 field);

    /**
     * @notice Reverts when replacing an institution and the new id already exists
     */
    error ReplacementIdConflict(bytes32 newId);

    /**
     * @notice Reverts when attempting to update to the same address
     */
    error SameAddress();
}
