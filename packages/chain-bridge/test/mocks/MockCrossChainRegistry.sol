// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainRegistry} from "../../src/interfaces/ICrossChainRegistry.sol";

contract MockCrossChainRegistry is ICrossChainRegistry {
    address private _bridgeRouter;
    mapping(address => bool) private _isExecutor;

    // Constants getters
    function PEER_RELATIONSHIP() external pure returns (bytes32) {
        return keccak256("PEER_RELATIONSHIP");
    }
    function EXECUTOR_RELATIONSHIP() external pure returns (bytes32) {
        return keccak256("EXECUTOR_RELATIONSHIP");
    }

    // Core/other functions not used in these tests - provide minimal stubs to satisfy interface
    function registerRelationship(
        address,
        address,
        uint16,
        uint16,
        bytes32
    ) external {}
    function unregisterRelationship(address, bytes32, uint16) external {}

    function bridgeRouter() external view returns (address) {
        return _bridgeRouter;
    }
    function setBridgeRouter(address newBridgeRouter) external {
        _bridgeRouter = newBridgeRouter;
    }

    function getAllTargetsForSource(
        address,
        bytes32
    ) external view returns (address[] memory, uint16[] memory) {
        address[] memory a;
        uint16[] memory b;
        return (a, b);
    }
    function getSourceForTarget(
        uint16,
        uint16,
        address,
        bytes32
    ) external view returns (address) {
        return address(0);
    }
    function isValidCrossChainPair(
        address,
        address,
        uint16,
        uint16,
        bytes32
    ) external view returns (bool) {
        return false;
    }
    function getRelationship(
        address,
        bytes32
    ) external view returns (CrossChainRelation memory) {
        return
            CrossChainRelation({
                sourceContract: address(0),
                targetContract: address(0),
                sourceChainId: 0,
                targetChainId: 0,
                relationshipType: bytes32(0)
            });
    }
    function getRelationshipByTarget(
        address,
        bytes32,
        uint16
    ) external view returns (CrossChainRelation memory) {
        return
            CrossChainRelation({
                sourceContract: address(0),
                targetContract: address(0),
                sourceChainId: 0,
                targetChainId: 0,
                relationshipType: bytes32(0)
            });
    }
    function getRegisteredSourceContracts(
        bytes32
    ) external view returns (address[] memory) {
        address[] memory a;
        return a;
    }
    function isSourceContractRegistered(
        address,
        bytes32
    ) external view returns (bool) {
        return false;
    }
    function getRelationshipCount(bytes32) external view returns (uint256) {
        return 0;
    }
    function getSupportedRelationshipTypes()
        external
        view
        returns (bytes32[] memory)
    {
        bytes32[] memory a;
        return a;
    }
    function addSupportedRelationshipType(bytes32) external {}
    function currentChainId() external view returns (uint16) {
        return 0;
    }
    function getAdapterPeer(address, uint16) external view returns (address) {
        return address(0);
    }
    function isValidAdapterPeer(
        address,
        address,
        uint16,
        uint16
    ) external view returns (bool) {
        return false;
    }

    // Executor functions used by subject under test
    function registerExecutor(address executor) external {
        _isExecutor[executor] = true;
    }
    function removeExecutor(address executor) external {
        _isExecutor[executor] = false;
    }
    function isAuthorizedExecutor(
        address executor
    ) external view returns (bool) {
        return _isExecutor[executor];
    }
}
