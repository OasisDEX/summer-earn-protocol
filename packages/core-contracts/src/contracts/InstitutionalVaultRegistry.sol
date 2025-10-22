// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInstitutionalVaultRegistry} from "../interfaces/IInstitutionalVaultRegistry.sol";
import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title InstitutionalVaultRegistry
 * @notice Single source of truth registry for institutional vault wiring.
 * @dev Governor-managed via ProtocolAccessManaged. Stores component addresses keyed by institution id.
 *      Update policy:
 *        - Only AdmiralsQuarters is updatable in-place
 *        - Other components are immutable; perform replacement with a new institution id instead
 *      Soft-disable preserves visibility and auditability of old institutions.
 */
contract InstitutionalVaultRegistry is IInstitutionalVaultRegistry, Ownable {
    mapping(bytes32 => IInstitutionalVaultRegistry.Institution)
        public institutions;

    constructor(address owner) Ownable(owner) {}

    /**
     * VIEW
     */
    /// @inheritdoc IInstitutionalVaultRegistry
    function getBytes32InstitutionId(
        string calldata name
    ) public pure returns (bytes32) {
        return bytes32(bytes(name));
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function getStringInstitutionId(
        bytes32 id
    ) public pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = id[i];
        }
        return string(bytesArray);
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function exists(bytes32 id) public view returns (bool) {
        return institutions[id].configurationManager != address(0);
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function getInstitution(
        bytes32 id
    )
        public
        view
        returns (IInstitutionalVaultRegistry.Institution memory institution)
    {
        institution = institutions[id];
        if (institution.configurationManager == address(0))
            revert InstitutionNotFound(id);
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function getConfigurationManager(bytes32 id) public view returns (address) {
        IInstitutionalVaultRegistry.Institution
            memory institution = getInstitution(id);
        return institution.configurationManager;
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function getProtocolAccessManager(
        bytes32 id
    ) public view returns (address) {
        IInstitutionalVaultRegistry.Institution
            memory institution = getInstitution(id);
        return institution.protocolAccessManager;
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function getAdmiralsQuarters(bytes32 id) public view returns (address) {
        IInstitutionalVaultRegistry.Institution
            memory institution = getInstitution(id);
        return institution.admiralsQuarters;
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function getHarborCommand(bytes32 id) public view returns (address) {
        IInstitutionalVaultRegistry.Institution
            memory institution = getInstitution(id);
        return
            IConfigurationManager(institution.configurationManager)
                .harborCommand();
    }

    /**
     * MANAGEMENT
     */

    /// @inheritdoc IInstitutionalVaultRegistry
    function addInstitution(
        bytes32 id,
        IInstitutionalVaultRegistry.Institution calldata institution
    ) external onlyOwner {
        if (exists(id)) revert InstitutionAlreadyExists(id);
        if (
            institution.configurationManager == address(0) ||
            institution.protocolAccessManager == address(0) ||
            institution.admiralsQuarters == address(0)
        ) revert AddressZero();

        institutions[id] = institution;

        emit InstitutionAdded(
            id,
            institution.configurationManager,
            institution.protocolAccessManager,
            institution.admiralsQuarters
        );
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function removeInstitution(bytes32 id) external onlyOwner {
        if (!exists(id)) revert InstitutionNotFound(id);
        delete institutions[id];
        emit InstitutionRemoved(id);
    }

    /// @inheritdoc IInstitutionalVaultRegistry
    function updateAdmiralsQuarters(
        bytes32 id,
        address newAdmiralsQuarters
    ) external onlyOwner {
        if (!exists(id)) revert InstitutionNotFound(id);
        IInstitutionalVaultRegistry.Institution
            storage institution = institutions[id];
        if (newAdmiralsQuarters == address(0)) revert AddressZero();
        if (institution.admiralsQuarters == newAdmiralsQuarters)
            revert SameAddress();

        address previous = institution.admiralsQuarters;
        institution.admiralsQuarters = newAdmiralsQuarters;
        emit InstitutionAdmiralsQuartersUpdated(
            id,
            previous,
            newAdmiralsQuarters
        );
    }
}
