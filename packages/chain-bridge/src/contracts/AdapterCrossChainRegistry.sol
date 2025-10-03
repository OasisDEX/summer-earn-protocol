// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseCrossChainRegistry} from "./BaseCrossChainRegistry.sol";

/**
 * @title AdapterCrossChainRegistry
 * @notice Specialized registry for managing adapter peer relationships
 * @dev Inherits from BaseCrossChainRegistry and provides adapter-specific convenience functions.
 *      Only supports bidirectional pair registrations and removals for security and consistency.
 */
abstract contract AdapterCrossChainRegistry is BaseCrossChainRegistry {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the AdapterCrossChainRegistry
     * @param _accessManager Address of the access manager
     */
    constructor(
        address _accessManager
    ) BaseCrossChainRegistry(_accessManager) {}

    /*//////////////////////////////////////////////////////////////
                    ADAPTER PEER PAIR RELATIONSHIP CONVENIENCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the peer adapter address for a given source adapter and target chain
     * @param sourceAdapter Address of the source adapter
     * @param targetChainId Chain ID where the target adapter is deployed
     * @return targetAdapter Address of the target adapter
     */
    function getAdapterPeer(
        address sourceAdapter,
        uint16 targetChainId
    ) external view returns (address targetAdapter) {
        CrossChainRelation memory relation = _getRelationshipByTarget(
            sourceAdapter,
            PEER_RELATIONSHIP,
            targetChainId
        );
        return relation.targetContract;
    }

    /**
     * @notice Check if two adapters are registered as valid peers
     * @param sourceAdapter Address of the source adapter
     * @param targetAdapter Address of the target adapter
     * @param sourceChainId Chain ID where the source adapter is deployed
     * @param targetChainId Chain ID where the target adapter is deployed
     * @return True if the adapters are registered peers
     */
    function isValidAdapterPeer(
        address sourceAdapter,
        address targetAdapter,
        uint16 sourceChainId,
        uint16 targetChainId
    ) external view returns (bool) {
        return
            _isValidCrossChainPair(
                sourceAdapter,
                targetAdapter,
                sourceChainId,
                targetChainId,
                PEER_RELATIONSHIP
            );
    }

    /**
     * @notice Register a bidirectional peer relationship between two adapters in one call
     * @dev Convenience that registers (adapterA -> adapterB) and (adapterB -> adapterA)
     * @param adapterA Address of the first adapter
     * @param adapterB Address of the second adapter
     * @param chainA Chain ID where adapterA is deployed
     * @param chainB Chain ID where adapterB is deployed
     */
    function registerAdapterPeerPair(
        address adapterA,
        address adapterB,
        uint16 chainA,
        uint16 chainB
    ) external onlyGovernor {
        _registerRelationship(
            adapterA,
            adapterB,
            chainA,
            chainB,
            PEER_RELATIONSHIP
        );
        _registerRelationship(
            adapterB,
            adapterA,
            chainB,
            chainA,
            PEER_RELATIONSHIP
        );
    }

    /**
     * @notice Unregister a bidirectional peer relationship between two adapters in one call
     * @param adapterA Address of the first adapter
     * @param adapterB Address of the second adapter
     * @param chainA Chain ID where adapterA is deployed
     * @param chainB Chain ID where adapterB is deployed
     */
    function unregisterAdapterPeerPair(
        address adapterA,
        address adapterB,
        uint16 chainA,
        uint16 chainB
    ) external onlyGovernor {
        _unregisterRelationship(adapterA, PEER_RELATIONSHIP, chainB);
        _unregisterRelationship(adapterB, PEER_RELATIONSHIP, chainA);
    }

    /**
     * @notice Get all peer adapters for a given source adapter
     * @param sourceAdapter Address of the source adapter
     * @return targetAdapters Array of target adapter addresses
     * @return targetChainIds Array of target chain IDs
     */
    function getAdapterPeers(
        address sourceAdapter
    )
        external
        view
        returns (
            address[] memory targetAdapters,
            uint16[] memory targetChainIds
        )
    {
        return _getTargetsForSource(sourceAdapter, PEER_RELATIONSHIP);
    }

    /**
     * @notice Get the first peer adapter for a given source adapter
     * @param sourceAdapter Address of the source adapter
     * @return targetAdapter Address of the target adapter
     * @return targetChainId Chain ID where the target adapter is deployed
     */
    function getFirstAdapterPeer(
        address sourceAdapter
    ) external view returns (address targetAdapter, uint16 targetChainId) {
        return _getTargetForSource(sourceAdapter, PEER_RELATIONSHIP);
    }

    /**
     * @notice Check if an adapter is registered as a source for peer relationships
     * @param adapter Address of the adapter to check
     * @return isRegistered True if the adapter is registered as a source
     */
    function isAdapterRegistered(
        address adapter
    ) external view returns (bool isRegistered) {
        return _isSourceContractRegistered(adapter, PEER_RELATIONSHIP);
    }

    /**
     * @notice Get all registered adapter sources
     * @return adapters Array of registered adapter addresses
     */
    function getRegisteredAdapters()
        external
        view
        returns (address[] memory adapters)
    {
        return _getRegisteredSourceContracts(PEER_RELATIONSHIP);
    }

    /**
     * @notice Get the total number of registered adapter relationships
     * @return count The number of registered adapter relationships
     */
    function getAdapterRelationshipCount()
        external
        view
        returns (uint256 count)
    {
        return _getRelationshipCount(PEER_RELATIONSHIP);
    }
}
