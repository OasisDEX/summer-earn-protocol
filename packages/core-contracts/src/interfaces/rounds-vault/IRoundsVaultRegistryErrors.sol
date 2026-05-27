// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRoundsVaultBaseEnums} from "./IRoundsVaultBaseEnums.sol";

/**
 * @title IRoundsVaultRegistryErrors
 * @notice Custom errors for the RoundsVaultRegistry.
 */
interface IRoundsVaultRegistryErrors {
    /// @notice Reverts when registering a pair whose target vault is already registered.
    error PairAlreadyExists(bytes32 pairId);

    /// @notice Reverts when reading/updating a pair that does not exist.
    error PairNotFound(bytes32 pairId);

    /// @notice Reverts when neither inputVault nor outputVault is provided (at least one must be set).
    error NoVaultProvided();

    /// @notice Reverts when targetVault is the zero address.
    error TargetVaultZero();

    /// @notice Reverts when an input/output vault's `vault()` view does not match the declared target.
    /// @param vaultAddr  The rounds-vault that failed validation
    /// @param expected   Declared target vault
    /// @param actual     The address returned by `IRoundsVaultBase(vaultAddr).vault()`
    error TargetMismatch(address vaultAddr, address expected, address actual);

    /// @notice Reverts when reactivating a pair that is already active or deactivating one that is already inactive.
    error PairStateUnchanged(bytes32 pairId);

    /// @notice Reverts when an update would leave the pair with neither input nor output vault set.
    error UpdateWouldEmptyPair(bytes32 pairId);

    /// @notice Reverts when a provided rounds-vault's VAULT_TYPE does not match the slot it is being assigned to.
    /// @param vaultAddr The misclassified vault.
    /// @param expected  The flavor required by the slot (Input or Output).
    /// @param actual    The flavor returned by the vault's `VAULT_TYPE()`.
    error VaultFlavorMismatch(
        address vaultAddr,
        IRoundsVaultBaseEnums.BaseVaultType expected,
        IRoundsVaultBaseEnums.BaseVaultType actual
    );

    /// @notice Reverts when a `setInputVault` / `setOutputVault` call is passed `address(0)`.
    /// @dev    The API forbids using a zero address as a "clear" sentinel — callers must use
    ///         `clearInputVault` / `clearOutputVault` to drop a side.
    error UseClearInsteadOfZero(bytes32 pairId);
}
