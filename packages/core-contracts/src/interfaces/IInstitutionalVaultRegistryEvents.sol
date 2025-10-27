// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IInstitutionalVaultRegistryEvents
 * @notice Events for the Institutional Vault Registry
 */
interface IInstitutionalVaultRegistryEvents {
    /**
     * @notice Emitted when a new institution is added
     * @param id The id of the institution
     */
    event InstitutionAdded(
        bytes32 indexed id,
        address configurationManager,
        address protocolAccessManager,
        address admiralsQuarters
    );

    /**
     * @notice Emitted when an institution is disabled
     */
    event InstitutionRemoved(bytes32 indexed id);

    /**
     * @notice Emitted when an institution's AdmiralsQuarters address is updated
     */
    event InstitutionAdmiralsQuartersUpdated(
        bytes32 indexed id,
        address previousAdmiralsQuarters,
        address newAdmiralsQuarters
    );

    /**
     * @notice Emitted when an institution is replaced with a new one
     */
    event InstitutionReplaced(bytes32 indexed oldId, bytes32 indexed newId);
}
