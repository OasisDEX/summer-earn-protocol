// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRoundsVaultRegistryErrors} from "./IRoundsVaultRegistryErrors.sol";
import {IRoundsVaultRegistryEvents} from "./IRoundsVaultRegistryEvents.sol";

/**
 * @title IRoundsVaultRegistry
 * @notice Discovery registry for `RoundsVaultInput` / `RoundsVaultOutput` pairs that wrap institutional
 *         FleetCommanders. The companion subgraph spawns per-vault data sources off of this contract's
 *         events, so the event shape is part of the public contract.
 *
 * @dev Pairs are keyed by `keccak256(targetVault)` because every FleetCommander has at most one
 *      active rounds-vault pair at any time. Deactivation is soft to preserve history for indexers.
 *
 * @dev Mutator functions are `onlyOwner` (OpenZeppelin `Ownable`). The registry is shared across
 *      institutions (each institution operates its own `ProtocolAccessManagerV2`), so the owner is
 *      expected to be the protocol multisig — distinct from any per-fleet Governor role.
 */
interface IRoundsVaultRegistry is
    IRoundsVaultRegistryErrors,
    IRoundsVaultRegistryEvents
{
    /**
     * @notice On-chain record of a rounds-vault pair.
     * @dev `inputVault` or `outputVault` may be zero if only one flavor is deployed for this fleet.
     */
    struct RoundsVaultPair {
        address inputVault;
        address outputVault;
        address targetVault;
        bytes32 institutionId;
        bool active;
        uint64 registeredAt;
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Derive the storage key for a pair from its target vault address.
    /// @param targetVault The FleetCommander vault address to derive a pair id for.
    /// @return The `keccak256(targetVault)` pair id used to key the registry.
    function getPairId(address targetVault) external pure returns (bytes32);

    /// @notice Returns true if a pair with this id has ever been registered (may be inactive).
    /// @param pairId The pair id to check.
    /// @return True if a record exists for `pairId` (active or deactivated), false otherwise.
    function exists(bytes32 pairId) external view returns (bool);

    /// @notice Returns the stored pair, reverting if it does not exist.
    /// @param pairId The pair id to look up.
    /// @return pair The stored `RoundsVaultPair` record for `pairId`.
    function getPair(
        bytes32 pairId
    ) external view returns (RoundsVaultPair memory pair);

    /// @notice Returns the pair associated with a given target vault, reverting if not registered.
    /// @param targetVault The FleetCommander vault address whose pair is being looked up.
    /// @return pair The stored `RoundsVaultPair` record for the derived pair id.
    function getPairByTarget(
        address targetVault
    ) external view returns (RoundsVaultPair memory pair);

    /// @notice Returns the number of pairs ever registered (active + inactive).
    /// @return The total count of pair records in the enumerable list.
    function pairCount() external view returns (uint256);

    /// @notice Returns the pairId at a given index in the enumerable list.
    /// @param index Zero-based index into the enumerable list of registered pair ids.
    /// @return The pair id at position `index`.
    function pairIdAt(uint256 index) external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new rounds-vault pair for `targetVault`.
     * @dev Reverts if a pair already exists for this target, if `targetVault` is zero, if both
     *      input and output are zero, or if either provided vault's `vault()` view does not match
     *      `targetVault` or its `VAULT_TYPE()` does not match its slot. Owner-gated.
     * @param institutionId Caller-defined tag used to group pairs by institution off-chain.
     * @param targetVault The FleetCommander both rounds-vaults wrap. Must be non-zero.
     * @param inputVault The Input-flavor rounds-vault address, or `address(0)` if only the Output
     *                   side is being registered.
     * @param outputVault The Output-flavor rounds-vault address, or `address(0)` if only the Input
     *                    side is being registered. At least one of `inputVault` / `outputVault` must
     *                    be non-zero.
     */
    function registerPair(
        bytes32 institutionId,
        address targetVault,
        address inputVault,
        address outputVault
    ) external;

    /**
     * @notice Set or replace the input-flavor vault for an existing pair.
     * @dev    Reverts with:
     *         - `PairNotFound(pairId)` if no pair is registered for `pairId`.
     *         - `UseClearInsteadOfZero(pairId)` if `inputVault == address(0)` (use `clearInputVault` instead).
     *         - `TargetMismatch` if `inputVault.vault() != pair.targetVault`.
     *         - `VaultFlavorMismatch` if `inputVault.VAULT_TYPE() != Input`.
     *         Emits `RoundsVaultPairUpdated` with the post-change values. Owner-gated.
     * @param pairId The pair id whose input slot is being set.
     * @param inputVault The new Input-flavor rounds-vault address (must be non-zero).
     */
    function setInputVault(bytes32 pairId, address inputVault) external;

    /**
     * @notice Set or replace the output-flavor vault for an existing pair.
     * @dev    Same validation rules as `setInputVault` but requires `VAULT_TYPE == Output`.
     *         Reverts with `PairNotFound(pairId)` if no pair is registered for `pairId`.
     *         Owner-gated.
     * @param pairId The pair id whose output slot is being set.
     * @param outputVault The new Output-flavor rounds-vault address (must be non-zero).
     */
    function setOutputVault(bytes32 pairId, address outputVault) external;

    /**
     * @notice Drop the input vault from a pair.
     * @dev    Reverts with `PairNotFound(pairId)` if no pair is registered for `pairId`, or with
     *         `UpdateWouldEmptyPair(pairId)` if the output side is also empty.
     *         Emits `RoundsVaultPairUpdated`. Owner-gated.
     * @param pairId The pair id whose input slot should be cleared.
     */
    function clearInputVault(bytes32 pairId) external;

    /**
     * @notice Drop the output vault from a pair.
     * @dev    Reverts with `PairNotFound(pairId)` if no pair is registered for `pairId`, or with
     *         `UpdateWouldEmptyPair(pairId)` if the input side is also empty.
     *         Emits `RoundsVaultPairUpdated`. Owner-gated.
     * @param pairId The pair id whose output slot should be cleared.
     */
    function clearOutputVault(bytes32 pairId) external;

    /// @notice Mark a pair inactive without removing it. Owner-gated.
    /// @dev Reverts with `PairNotFound(pairId)` if no pair is registered for `pairId`, or with
    ///      `PairStateUnchanged(pairId)` if the pair is already inactive.
    ///      Emits `RoundsVaultPairDeactivated`.
    /// @param pairId The pair id to deactivate.
    function deactivatePair(bytes32 pairId) external;

    /// @notice Re-enable a previously-deactivated pair. Owner-gated.
    /// @dev Reverts with `PairNotFound(pairId)` if no pair is registered for `pairId`, or with
    ///      `PairStateUnchanged(pairId)` if the pair is already active.
    ///      Emits `RoundsVaultPairReactivated`.
    /// @param pairId The pair id to reactivate.
    function reactivatePair(bytes32 pairId) external;
}
