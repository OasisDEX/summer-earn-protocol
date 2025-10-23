// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInstitutionalVaultRegistryErrors} from "./IInstitutionalVaultRegistryErrors.sol";
import {IInstitutionalVaultRegistryEvents} from "./IInstitutionalVaultRegistryEvents.sol";

/**
 * @title IInstitutionalVaultRegistry
 * @notice Single source of truth for institutional vault wiring.
 * @dev Stores component addresses keyed by institution id (bytes32). Governor-managed.
 */
interface IInstitutionalVaultRegistry is
    IInstitutionalVaultRegistryErrors,
    IInstitutionalVaultRegistryEvents
{
    struct Institution {
        address configurationManager;
        address protocolAccessManager;
        address admiralsQuarters;
    }
    /**
     * VIEW
     */

    /**
     * @notice Derives a bytes32 institution id from a UTF-8 string name.
     * @dev This is a raw cast: strings longer than 32 bytes are truncated; shorter strings are right-padded with zeros.
     *      Use only if the naming convention guarantees <= 32 bytes and deterministic casing/encoding.
     * @param name Human-readable institution name (UTF-8)
     * @return id bytes32 identifier suitable for on-chain keys
     */
    function getBytes32InstitutionId(
        string calldata name
    ) external pure returns (bytes32 id);

    /**
     * @notice Converts a bytes32 institution id back to a 32-byte string.
     * @dev Returns the full 32-byte string
     * @param id bytes32 institution identifier
     * @return name 32-byte string representation (may contain null bytes)
     */
    function getStringInstitutionId(
        bytes32 id
    ) external pure returns (string memory name);

    /**
     * @notice Returns true if an institution id exists (active or disabled)
     */
    function exists(bytes32 id) external view returns (bool);

    /**
     * @notice Returns the full institution wiring for institution with id `id`
     * @dev Reverts if the institution does not exist
     */
    function getInstitution(
        bytes32 id
    ) external view returns (Institution memory institution);

    /**
     * @notice Returns the ConfigurationManager for institution with id `id`
     * @dev Reverts if the institution does not exist
     */
    function getConfigurationManager(
        bytes32 id
    ) external view returns (address);

    /**
     * @notice Returns the ProtocolAccessManager for institution with id `id`
     * @dev Reverts if the institution does not exist
     */
    function getProtocolAccessManager(
        bytes32 id
    ) external view returns (address);

    /**
     * @notice Returns the AdmiralsQuarters for institution with id `id`
     * @dev Reverts if the institution does not exist
     */
    function getAdmiralsQuarters(bytes32 id) external view returns (address);

    /**
     * @notice Returns the HarborCommand for institution with id `id`
     * @dev Reverts if the institution does not exist; value is read from the institution's ConfigurationManager
     */
    function getHarborCommand(bytes32 id) external view returns (address);

    /**
     * MANAGEMENT (onlyGovernor)
     */

    /**
     * @notice Adds a new institution wiring
     */
    function addInstitution(
        bytes32 id,
        Institution calldata institution
    ) external;

    /**
     * @notice Removes an existing institution id (keeps data visible)
     */
    function removeInstitution(bytes32 id) external;

    /**
     * @notice Updates only the AdmiralsQuarters address for institution with id `id`
     */
    function updateAdmiralsQuarters(
        bytes32 id,
        address newAdmiralsQuarters
    ) external;
}
