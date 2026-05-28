// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRoundsVaultBase} from "../../interfaces/rounds-vault/IRoundsVaultBase.sol";
import {IRoundsVaultBaseEnums} from "../../interfaces/rounds-vault/IRoundsVaultBaseEnums.sol";
import {IRoundsVaultRegistry} from "../../interfaces/rounds-vault/IRoundsVaultRegistry.sol";

/**
 * @title RoundsVaultRegistry
 * @notice On-chain registry of (input, output, target) tuples for institutional rounds vaults.
 *
 * @dev Authoritative discovery point for the rounds-vaults subgraph. Mutators are `onlyOwner`
 *      (OpenZeppelin `Ownable`). The owner is expected to be the protocol multisig because the
 *      registry is shared across institutions while each institution operates its own
 *      `ProtocolAccessManagerV2`.
 *
 * @dev Pairs are keyed by `keccak256(targetVault)` rather than an external id, because every
 *      FleetCommander has at most one rounds-vault pair at any time. Soft-deactivation preserves
 *      indexer history; a redeployed vault is registered as a new pair against a new target.
 */
contract RoundsVaultRegistry is Ownable, IRoundsVaultRegistry {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => RoundsVaultPair) private _pairs;
    bytes32[] private _pairIds;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the registry with `owner` as the sole address authorized to register, update,
     *         clear, deactivate, or reactivate pairs. The owner can transfer ownership via the
     *         inherited `Ownable` interface.
     * @param owner Initial owner of the registry (typically the protocol multisig).
     */
    constructor(address owner) Ownable(owner) {}

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
    function pairIdAt(uint256 index) external view override returns (bytes32) {
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
    ) external override onlyOwner {
        if (targetVault == address(0)) revert TargetVaultZero();
        if (inputVault == address(0) && outputVault == address(0)) {
            revert NoVaultProvided();
        }

        bytes32 pairId = getPairId(targetVault);
        if (exists(pairId)) revert PairAlreadyExists(pairId);

        _validateVault(
            inputVault,
            targetVault,
            IRoundsVaultBaseEnums.BaseVaultType.Input
        );
        _validateVault(
            outputVault,
            targetVault,
            IRoundsVaultBaseEnums.BaseVaultType.Output
        );

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
    function setInputVault(
        bytes32 pairId,
        address inputVault
    ) external override onlyOwner {
        if (inputVault == address(0)) revert UseClearInsteadOfZero(pairId);

        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);

        _validateVault(
            inputVault,
            pair.targetVault,
            IRoundsVaultBaseEnums.BaseVaultType.Input
        );
        pair.inputVault = inputVault;

        emit RoundsVaultPairUpdated(pairId, pair.inputVault, pair.outputVault);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function setOutputVault(
        bytes32 pairId,
        address outputVault
    ) external override onlyOwner {
        if (outputVault == address(0)) revert UseClearInsteadOfZero(pairId);

        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);

        _validateVault(
            outputVault,
            pair.targetVault,
            IRoundsVaultBaseEnums.BaseVaultType.Output
        );
        pair.outputVault = outputVault;

        emit RoundsVaultPairUpdated(pairId, pair.inputVault, pair.outputVault);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function clearInputVault(bytes32 pairId) external override onlyOwner {
        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
        if (pair.outputVault == address(0)) revert UpdateWouldEmptyPair(pairId);

        pair.inputVault = address(0);
        emit RoundsVaultPairUpdated(pairId, pair.inputVault, pair.outputVault);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function clearOutputVault(bytes32 pairId) external override onlyOwner {
        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
        if (pair.inputVault == address(0)) revert UpdateWouldEmptyPair(pairId);

        pair.outputVault = address(0);
        emit RoundsVaultPairUpdated(pairId, pair.inputVault, pair.outputVault);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function deactivatePair(bytes32 pairId) external override onlyOwner {
        RoundsVaultPair storage pair = _pairs[pairId];
        if (pair.targetVault == address(0)) revert PairNotFound(pairId);
        if (!pair.active) revert PairStateUnchanged(pairId);

        pair.active = false;
        emit RoundsVaultPairDeactivated(pairId);
    }

    /// @inheritdoc IRoundsVaultRegistry
    function reactivatePair(bytes32 pairId) external override onlyOwner {
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
     * @dev Validates that a non-zero rounds-vault wraps `expectedTarget` and matches
     *      `expectedType`. No-op for `address(0)` so callers can pass one side as zero
     *      when only one flavor exists.
     */
    function _validateVault(
        address vaultAddr,
        address expectedTarget,
        IRoundsVaultBaseEnums.BaseVaultType expectedType
    ) private view {
        if (vaultAddr == address(0)) return;

        IRoundsVaultBase v = IRoundsVaultBase(vaultAddr);

        address actualTarget = v.vault();
        if (actualTarget != expectedTarget) {
            revert TargetMismatch(vaultAddr, expectedTarget, actualTarget);
        }

        IRoundsVaultBaseEnums.BaseVaultType actualType = v.VAULT_TYPE();
        if (actualType != expectedType) {
            revert VaultFlavorMismatch(vaultAddr, expectedType, actualType);
        }
    }
}
