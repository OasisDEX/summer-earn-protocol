// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInstitutionalVaultRegistry} from "../interfaces/IInstitutionalVaultRegistry.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
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
        private _institutions;

    constructor(address owner) Ownable(owner) {}

    /**
     * VIEW
     */

    function exists(bytes32 id) public view returns (bool) {
        return _institutions[id].configurationManager != address(0);
    }

    function isActive(bytes32 id) public view returns (bool) {
        if (!exists(id)) revert InstitutionNotFound(id);
        return _institutions[id].active;
    }

    function getInstitution(
        bytes32 id
    )
        public
        view
        returns (IInstitutionalVaultRegistry.Institution memory institution)
    {
        institution = _institutions[id];
        if (institution.configurationManager == address(0))
            revert InstitutionNotFound(id);
    }

    function getConfigurationManager(bytes32 id) public view returns (address) {
        IInstitutionalVaultRegistry.Institution memory inst = getInstitution(
            id
        );
        return inst.configurationManager;
    }

    function getProtocolAccessManager(
        bytes32 id
    ) public view returns (address) {
        IInstitutionalVaultRegistry.Institution memory inst = getInstitution(
            id
        );
        return inst.protocolAccessManager;
    }

    function getAdmiralsQuarters(bytes32 id) public view returns (address) {
        IInstitutionalVaultRegistry.Institution memory inst = getInstitution(
            id
        );
        return inst.admiralsQuarters;
    }

    function getHarborCommand(bytes32 id) public view returns (address) {
        IInstitutionalVaultRegistry.Institution memory inst = getInstitution(
            id
        );
        return IConfigurationManager(inst.configurationManager).harborCommand();
    }

    /**
     * MANAGEMENT
     */

    function addInstitution(
        bytes32 id,
        IInstitutionalVaultRegistry.Institution calldata institution
    ) external onlyOwner {
        if (exists(id)) revert InstitutionAlreadyExists(id);
        if (
            institution.configurationManager == address(0) ||
            institution.protocolAccessManager == address(0) ||
            institution.admiralsQuarters == address(0)
        ) revert ZeroAddress();

        IInstitutionalVaultRegistry.Institution memory toStore = institution;
        toStore.active = true;
        _institutions[id] = toStore;

        emit InstitutionAdded(
            id,
            toStore.configurationManager,
            toStore.protocolAccessManager,
            toStore.admiralsQuarters
        );
    }

    function disableInstitution(bytes32 id) external onlyOwner {
        if (!exists(id)) revert InstitutionNotFound(id);
        if (!_institutions[id].active) revert InstitutionIsDisabled(id);
        _institutions[id].active = false;
        emit InstitutionDisabled(id);
    }

    function updateAdmiralsQuarters(
        bytes32 id,
        address newAdmiralsQuarters
    ) external onlyOwner {
        if (!exists(id)) revert InstitutionNotFound(id);
        IInstitutionalVaultRegistry.Institution storage inst = _institutions[
            id
        ];
        if (!inst.active) revert InstitutionIsDisabled(id);
        if (newAdmiralsQuarters == address(0)) revert ZeroAddress();
        if (inst.admiralsQuarters == newAdmiralsQuarters) revert SameAddress();

        address previous = inst.admiralsQuarters;
        inst.admiralsQuarters = newAdmiralsQuarters;
        emit InstitutionAdmiralsQuartersUpdated(
            id,
            previous,
            newAdmiralsQuarters
        );
    }
}
