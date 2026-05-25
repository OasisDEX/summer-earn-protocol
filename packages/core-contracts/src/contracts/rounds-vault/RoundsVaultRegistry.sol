// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManagedV2} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedV2.sol";

import {IERC4626MultiTokenWrapper} from "../../interfaces/extensions/ERC4626MultiTokenWrapper/IERC4626MultiTokenWrapper.sol";
import {IRoundsVaultRegistry} from "../../interfaces/rounds-vault/IRoundsVaultRegistry.sol";

/**
 * @title RoundsVaultRegistry
 * @notice On-chain registry of (input, output, target) tuples for institutional rounds vaults.
 * @dev    Authoritative discovery point for the rounds-vaults subgraph. Governor-gated through
 *         ProtocolAccessManagedV2 to align with the rounds-vault contracts themselves.
 *
 *         Pairs are keyed by `keccak256(targetVault)` rather than an external id, because every
 *         FleetCommander has at most one rounds-vault pair at any time. Soft-deactivation preserves
 *         indexer history; a redeployed vault is registered as a new pair against a new target.
 */
contract RoundsVaultRegistry is ProtocolAccessManagedV2, IRoundsVaultRegistry {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => RoundsVaultPair) private _pairs;
    bytes32[] private _pairIds;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address accessManager
    ) ProtocolAccessManagedV2(accessManager) {}

    /*//////////////////////////////////////////////////////////////
                                  VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRoundsVaultRegistry
    function getPairId(
        address targetVault
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(targetVault));
    }

    /// @inheritdoc IRoundsVaultRegistry
    function exists(bytes32 pairId) public view override returns (bool) {
        return _pairs[pairId].targetVault != address(0);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function getPair(
        bytes32 pairId
    ) external view override returns (RoundsVaultPair memory pair) {
        pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function getPairByTarget(
        address targetVault
    ) external view override returns (RoundsVaultPair memory pair) {
        bytes32 pairId = getPairId(targetVault);
        pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function pairCount() external view override returns (uint256) {
        return _pairIds.length;
    }

    /// @inheritdoc IRoundsVaultRegistry
    function pairIdAt(
        uint256 index
    ) external view override returns (bytes32) {
        return _pairIds[index];
    }

    /*//////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRoundsVaultRegistry
    function registerPair(
        bytes32 institutionId,
        address targetVault,
        address inputVault,
        address outputVault
    ) external override onlyGovernor {
        if (targetVault == address(0)) revert TargetVaultZero();
        if (inputVault == address(0) && outputVault == address(0)) {
            revert NoVaultProvided();
        }

        bytes32 pairId = getPairId(targetVault);
        if (exists(pairId)) revert PairAlreadyExists(pairId);

        _validateVaultTarget(inputVault, targetVault);
        _validateVaultTarget(outputVault, targetVault);

        _pairs[pairId] = RoundsVaultPair({
            inputVault: inputVault,
            outputVault: outputVault,
            targetVault: targetVault,
            institutionId: institutionId,
            active: true,
            registeredAt: uint64(block.timestamp)
        });
        _pairIds.push(pairId);

        emit RoundsVaultPairRegistered(
            pairId,
            institutionId,
            targetVault,
            inputVault,
            outputVault
        );
    }

    /// @inheritdoc IRoundsVaultRegistry
    function updatePair(
        bytes32 pairId,
        address inputVault,
        address outputVault
    ) external override onlyGovernor {
        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);

        address newInput = inputVault == address(0)
            ? pair.inputVault
            : inputVault;
        address newOutput = outputVault == address(0)
            ? pair.outputVault
            : outputVault;

        if (newInput == address(0) && newOutput == address(0)) {
            revert UpdateWouldEmptyPair(pairId);
        }

        if (inputVault != address(0)) {
            _validateVaultTarget(inputVault, pair.targetVault);
            pair.inputVault = inputVault;
        }
        if (outputVault != address(0)) {
            _validateVaultTarget(outputVault, pair.targetVault);
            pair.outputVault = outputVault;
        }

        emit RoundsVaultPairUpdated(pairId, pair.inputVault, pair.outputVault);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function deactivatePair(
        bytes32 pairId
    ) external override onlyGovernor {
        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
        if (!pair.active) revert PairStateUnchanged(pairId);

        pair.active = false;
        emit RoundsVaultPairDeactivated(pairId);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function reactivatePair(
        bytes32 pairId
    ) external override onlyGovernor {
        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
        if (pair.active) revert PairStateUnchanged(pairId);

        pair.active = true;
        emit RoundsVaultPairReactivated(pairId);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Confirms that a non-zero rounds-vault address actually wraps `expectedTarget`. No-op for
     *      zero addresses so callers can pass one side as zero when only one flavor exists.
     */
    function _validateVaultTarget(
        address vaultAddr,
        address expectedTarget
    ) private view {
        if (vaultAddr == address(0)) return;

        address actual = IERC4626MultiTokenWrapper(vaultAddr).vault();
        if (actual != expectedTarget) {
            revert TargetMismatch(vaultAddr, expectedTarget, actual);
        }
    }
}
