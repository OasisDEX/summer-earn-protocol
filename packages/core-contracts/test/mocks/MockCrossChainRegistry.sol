// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";

contract MockCrossChainRegistry is ICrossChainRegistry {
    mapping(address => CrossChainRelation) private arkToProxy;
    mapping(bytes32 => address) private proxyToArk;

    uint16 public currentChainId = 1;

    function _getTargetKey(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    sourceChainId,
                    targetChainId,
                    targetContract,
                    relationshipType
                )
            );
    }

    function registerCrossChainRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external {}

    function unregisterCrossChainRelationship(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external {}

    function getTargetForSource(
        address sourceContract,
        bytes32
    ) external view returns (address, uint16) {
        ICrossChainRegistry.CrossChainRelation memory relation = arkToProxy[
            sourceContract
        ];
        return (relation.targetContract, relation.targetChainId);
    }

    function getTargetsForSource(
        address sourceContract,
        bytes32
    ) external view returns (address[] memory, uint16[] memory) {
        ICrossChainRegistry.CrossChainRelation memory relation = arkToProxy[
            sourceContract
        ];
        if (relation.sourceContract != address(0)) {
            address[] memory targets = new address[](1);
            uint16[] memory chainIds = new uint16[](1);
            targets[0] = relation.targetContract;
            chainIds[0] = relation.targetChainId;
            return (targets, chainIds);
        }
        return (new address[](0), new uint16[](0));
    }

    function getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) external view returns (address) {
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetChainId,
            targetContract,
            relationshipType
        );
        return proxyToArk[targetKey];
    }

    function isSourceContractRegistered(
        address sourceContract,
        bytes32
    ) external view returns (bool) {
        return arkToProxy[sourceContract].sourceContract == sourceContract;
    }

    function setMockProxy(
        address ark,
        address proxy,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) public {
        arkToProxy[ark] = CrossChainRelation({
            sourceContract: ark,
            targetContract: proxy,
            sourceChainId: sourceChainId,
            targetChainId: targetChainId,
            relationshipType: relationshipType
        });
        bytes32 targetKey = _getTargetKey(
            sourceChainId,
            targetChainId,
            proxy,
            relationshipType
        );
        proxyToArk[targetKey] = ark;
    }

    function getRelationshipCount(bytes32) external pure returns (uint256) {
        return 0;
    }

    function getSupportedRelationshipTypes()
        external
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory supported = new bytes32[](1);
        supported[0] = keccak256("ARK_FLEET");
        return supported;
    }

    function getRelationship(
        address sourceContract,
        bytes32
    ) external view returns (CrossChainRelation memory) {
        return arkToProxy[sourceContract];
    }

    function getRelationshipByTarget(
        address sourceContract,
        bytes32 relationshipType,
        uint16 targetChainId
    ) external view returns (CrossChainRelation memory) {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        // Validate that the target chain ID matches
        if (
            relation.sourceContract != address(0) &&
            relation.targetChainId == targetChainId
        ) {
            return relation;
        }
        // Revert just like the real registry does
        revert RelationshipDoesNotExist(
            sourceContract,
            relationshipType,
            targetChainId
        );
    }

    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32
    ) external view returns (bool) {
        CrossChainRelation memory relation = arkToProxy[sourceContract];
        return
            relation.targetContract == targetContract &&
            relation.sourceChainId == sourceChainId &&
            relation.targetChainId == targetChainId;
    }

    function getRegisteredSourceContracts(
        bytes32
    ) external pure returns (address[] memory sourceContracts) {
        // Return empty array for mock implementation
        return new address[](0);
    }
}
