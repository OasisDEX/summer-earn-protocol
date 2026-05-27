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
    function getPairId(address targetVault) external pure returns (bytes32);

    /// @notice Returns true if a pair with this id has ever been registered (may be inactive).
    function exists(bytes32 pairId) external view returns (bool);

    /// @notice Returns the stored pair, reverting if it does not exist.
    function getPair(
        bytes32 pairId
    ) external view returns (RoundsVaultPair memory pair);

    /// @notice Returns the pair associated with a given target vault, reverting if not registered.
    function getPairByTarget(
        address targetVault
    ) external view returns (RoundsVaultPair memory pair);

    /// @notice Returns the number of pairs ever registered (active + inactive).
    function pairCount() external view returns (uint256);

    /// @notice Returns the pairId at a given index in the enumerable list.
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
     *         - `UseClearInsteadOfZero(pairId)` if `inputVault == address(0)` (use `clearInputVault` instead).
     *         - `TargetMismatch` if `inputVault.vault() != pair.targetVault`.
     *         - `VaultFlavorMismatch` if `inputVault.VAULT_TYPE() != Input`.
     *         Emits `RoundsVaultPairUpdated` with the post-change values. Owner-gated.
     */
    function setInputVault(bytes32 pairId, address inputVault) external;

    /**
     * @notice Set or replace the output-flavor vault for an existing pair.
     * @dev    Same validation rules as `setInputVault` but requires `VAULT_TYPE == Output`.
     *         Owner-gated.
     */
    function setOutputVault(bytes32 pairId, address outputVault) external;

    /**
     * @notice Drop the input vault from a pair.
     * @dev    Reverts with `UpdateWouldEmptyPair(pairId)` if the output side is also empty.
     *         Emits `RoundsVaultPairUpdated`. Owner-gated.
     */
    function clearInputVault(bytes32 pairId) external;

    /**
     * @notice Drop the output vault from a pair.
     * @dev    Reverts with `UpdateWouldEmptyPair(pairId)` if the input side is also empty.
     *         Emits `RoundsVaultPairUpdated`. Owner-gated.
     */
    function clearOutputVault(bytes32 pairId) external;

    /// @notice Mark a pair inactive without removing it. Owner-gated.
    function deactivatePair(bytes32 pairId) external;

    /// @notice Re-enable a previously-deactivated pair. Owner-gated.
    function reactivatePair(bytes32 pairId) external;
}
