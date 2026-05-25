// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IRoundsVaultRegistryEvents
 * @notice Events emitted by the RoundsVaultRegistry.
 * @dev These events form the contract that the rounds-vaults subgraph keys off of for discovery.
 */
interface IRoundsVaultRegistryEvents {
    /**
     * @notice Emitted when a new rounds-vault pair is registered against a target FleetCommander.
     * @param pairId       keccak256 of the target vault address, uniquely identifying the pair
     * @param institutionId Institution this pair belongs to (matches InstitutionalVaultRegistry id)
     * @param targetVault  The FleetCommander both rounds vaults wrap
     * @param inputVault   RoundsVaultInput address (zero if only output is registered)
     * @param outputVault  RoundsVaultOutput address (zero if only input is registered)
     */
    event RoundsVaultPairRegistered(
        bytes32 indexed pairId,
        bytes32 indexed institutionId,
        address indexed targetVault,
        address inputVault,
        address outputVault
    );

    /**
     * @notice Emitted when one or both vault addresses of an existing pair are replaced.
     * @dev Used when a flavor that was previously zero is filled in, or when a vault is migrated.
     */
    event RoundsVaultPairUpdated(
        bytes32 indexed pairId,
        address inputVault,
        address outputVault
    );

    /**
     * @notice Emitted when a pair is soft-disabled. Data is preserved for indexer auditability.
     */
    event RoundsVaultPairDeactivated(bytes32 indexed pairId);

    /**
     * @notice Emitted when a previously-deactivated pair is re-enabled.
     */
    event RoundsVaultPairReactivated(bytes32 indexed pairId);
}
