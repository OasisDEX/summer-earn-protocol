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
        bool active;
    }
    /**
     * VIEW
     */

    /// @notice Returns true if an institution id exists (active or disabled)
    function exists(bytes32 id) external view returns (bool);

    /// @notice Returns true if an institution id is active
    function isActive(bytes32 id) external view returns (bool);

    /// @notice Returns the full institution wiring for `id`
    function getInstitution(
        bytes32 id
    ) external view returns (Institution memory institution);

    /// @notice Returns the ConfigurationManager for `id`
    function getConfigurationManager(
        bytes32 id
    ) external view returns (address);

    /// @notice Returns the ProtocolAccessManager for `id`
    function getProtocolAccessManager(
        bytes32 id
    ) external view returns (address);

    /// @notice Returns the AdmiralsQuarters for `id`
    function getAdmiralsQuarters(bytes32 id) external view returns (address);

    /// @notice Returns the HarborCommand for `id`
    function getHarborCommand(bytes32 id) external view returns (address);

    /**
     * MANAGEMENT (onlyGovernor)
     */

    /// @notice Adds a new institution wiring
    function addInstitution(
        bytes32 id,
        Institution calldata institution
    ) external;

    /// @notice Disables an existing institution id (keeps data visible)
    function disableInstitution(bytes32 id) external;

    /// @notice Updates only the AdmiralsQuarters address for `id`
    function updateAdmiralsQuarters(
        bytes32 id,
        address newAdmiralsQuarters
    ) external;
}
