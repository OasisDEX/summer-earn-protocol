// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainRegistry
 * @notice Centralized registry for managing cross-chain relationships between CrossChainArk and FleetProxy contracts
 * @dev Inherits from ProtocolAccessManaged for access control and implements ICrossChainRegistry
 */
contract CrossChainRegistry is ICrossChainRegistry, ProtocolAccessManaged {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Current chain ID for this registry deployment
    uint16 public immutable currentChainId;

    /// @notice Mapping from ark address to its proxy relationship
    mapping(address => ArkProxyRelation) private arkToProxy;

    /// @notice Mapping from proxy key (keccak256(abi.encode(sourceChainId, proxy))) to ark address
    mapping(bytes32 => address) private proxyToArk;

    /// @notice Mapping from ark address to relationship metadata
    mapping(address => RelationshipMetadata) private relationshipMetadata;

    /// @notice Array of all registered ark addresses for enumeration
    address[] private registeredArks;

    /// @notice Mapping from chain ID to array of proxy addresses for enumeration
    mapping(uint16 => address[]) private proxiesByChain;

    /// @notice Mapping to track if an ark is in the registeredArks array
    mapping(address => bool) private isArkInArray;

    /// @notice Mapping to track if a proxy is in the proxiesByChain array
    mapping(bytes32 => bool) private isProxyInArray; // key: keccak256(abi.encode(chainId, proxy))

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to initialize the CrossChainRegistry
     * @param _accessManager Address of the access manager contract
     * @param _currentChainId The chain ID where this registry is deployed
     */
    constructor(
        address _accessManager,
        uint16 _currentChainId
    ) ProtocolAccessManaged(_accessManager) {
        if (_currentChainId == 0) revert InvalidChainId(_currentChainId);

        currentChainId = _currentChainId;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function registerArkProxy(
        address ark,
        uint16 targetChainId,
        address proxy,
        string calldata description
    ) external onlyGovernor {
        // Input validation
        if (ark == address(0)) revert InvalidArk(ark);
        if (proxy == address(0)) revert InvalidProxy(proxy);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);

        // Check if ark is already registered
        if (arkToProxy[ark].proxy != address(0)) {
            revert RelationshipAlreadyExists(
                ark,
                arkToProxy[ark].targetChainId,
                arkToProxy[ark].proxy
            );
        }

        // Check if proxy is already registered to another ark
        bytes32 proxyKey = keccak256(abi.encode(currentChainId, proxy));
        address existingArk = proxyToArk[proxyKey];
        if (existingArk != address(0)) {
            revert ProxyAlreadyRegistered(proxy, targetChainId, existingArk);
        }

        // Create the relationship
        arkToProxy[ark] = ArkProxyRelation({
            proxy: proxy,
            targetChainId: targetChainId,
            isActive: true
        });

        // Create reverse mapping
        proxyToArk[proxyKey] = ark;

        // Store metadata
        relationshipMetadata[ark] = RelationshipMetadata({
            description: description,
            createdAt: block.timestamp,
            creator: msg.sender,
            configHash: keccak256(
                abi.encode(ark, targetChainId, proxy, description)
            )
        });

        // Add to enumeration arrays if not already present
        if (!isArkInArray[ark]) {
            registeredArks.push(ark);
            isArkInArray[ark] = true;
        }

        bytes32 proxyInArrayKey = keccak256(abi.encode(targetChainId, proxy));
        if (!isProxyInArray[proxyInArrayKey]) {
            proxiesByChain[targetChainId].push(proxy);
            isProxyInArray[proxyInArrayKey] = true;
        }

        emit ArkProxyRegistered(ark, targetChainId, proxy, msg.sender);
    }

    /// @inheritdoc ICrossChainRegistry
    function unregisterArkProxy(address ark) external onlyGovernor {
        if (ark == address(0)) revert InvalidArk(ark);

        ArkProxyRelation memory relation = arkToProxy[ark];
        if (relation.proxy == address(0)) {
            revert RelationshipDoesNotExist(ark);
        }

        // Remove reverse mapping
        bytes32 proxyKey = keccak256(
            abi.encode(currentChainId, relation.proxy)
        );
        delete proxyToArk[proxyKey];

        // Remove from main mapping
        delete arkToProxy[ark];
        delete relationshipMetadata[ark];

        // Remove from enumeration arrays
        _removeArkFromArray(ark);
        _removeProxyFromArray(relation.targetChainId, relation.proxy);

        emit ArkProxyUnregistered(ark, relation.targetChainId, relation.proxy);
    }

    /// @inheritdoc ICrossChainRegistry
    function updateRelationshipStatus(
        address ark,
        bool isActive
    ) external onlyGovernor {
        if (ark == address(0)) revert InvalidArk(ark);

        ArkProxyRelation storage relation = arkToProxy[ark];
        if (relation.proxy == address(0)) {
            revert RelationshipDoesNotExist(ark);
        }

        relation.isActive = isActive;

        emit RelationshipStatusUpdated(
            ark,
            relation.targetChainId,
            relation.proxy,
            isActive
        );
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getProxyForArk(
        address ark
    ) external view returns (address proxy, uint16 targetChainId) {
        ArkProxyRelation memory relation = arkToProxy[ark];
        if (relation.proxy == address(0)) {
            revert RelationshipDoesNotExist(ark);
        }
        return (relation.proxy, relation.targetChainId);
    }

    /// @inheritdoc ICrossChainRegistry
    function getArkForProxy(
        uint16 sourceChainId,
        address proxy
    ) external view returns (address ark) {
        bytes32 proxyKey = keccak256(abi.encode(sourceChainId, proxy));
        ark = proxyToArk[proxyKey];
        if (ark == address(0)) {
            revert RelationshipDoesNotExist(address(0));
        }
        return ark;
    }

    /// @inheritdoc ICrossChainRegistry
    function isValidArkProxyPair(
        address ark,
        uint16 targetChainId,
        address proxy
    ) external view returns (bool isValid) {
        ArkProxyRelation memory relation = arkToProxy[ark];
        return
            relation.proxy == proxy &&
            relation.targetChainId == targetChainId &&
            relation.isActive;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelation(
        address ark
    ) external view returns (ArkProxyRelation memory relation) {
        relation = arkToProxy[ark];
        if (relation.proxy == address(0)) {
            revert RelationshipDoesNotExist(ark);
        }
        return relation;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipMetadata(
        address ark
    ) external view returns (RelationshipMetadata memory metadata) {
        ArkProxyRelation memory relation = arkToProxy[ark];
        if (relation.proxy == address(0)) {
            revert RelationshipDoesNotExist(ark);
        }
        return relationshipMetadata[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredArks() external view returns (address[] memory arks) {
        return registeredArks;
    }

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredProxies(
        uint16 chainId
    ) external view returns (address[] memory proxies) {
        return proxiesByChain[chainId];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount() external view returns (uint256 count) {
        return registeredArks.length;
    }

    /// @inheritdoc ICrossChainRegistry
    function isArkRegistered(
        address ark
    ) external view returns (bool isRegistered) {
        return arkToProxy[ark].proxy != address(0);
    }

    /// @inheritdoc ICrossChainRegistry
    function isProxyRegistered(
        address proxy,
        uint16 chainId
    ) external view returns (bool isRegistered) {
        bytes32 proxyKey = keccak256(abi.encode(chainId, proxy));
        return proxyToArk[proxyKey] != address(0);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Removes an ark from the registeredArks array
     * @param ark The ark address to remove
     */
    function _removeArkFromArray(address ark) internal {
        uint256 length = registeredArks.length;
        for (uint256 i = 0; i < length; i++) {
            if (registeredArks[i] == ark) {
                // Move last element to current position and pop
                registeredArks[i] = registeredArks[length - 1];
                registeredArks.pop();
                isArkInArray[ark] = false;
                break;
            }
        }
    }

    /**
     * @notice Removes a proxy from the proxiesByChain array
     * @param chainId The chain ID where the proxy is located
     * @param proxy The proxy address to remove
     */
    function _removeProxyFromArray(uint16 chainId, address proxy) internal {
        address[] storage proxies = proxiesByChain[chainId];
        uint256 length = proxies.length;

        for (uint256 i = 0; i < length; i++) {
            if (proxies[i] == proxy) {
                // Move last element to current position and pop
                proxies[i] = proxies[length - 1];
                proxies.pop();

                bytes32 proxyInArrayKey = keccak256(abi.encode(chainId, proxy));
                isProxyInArray[proxyInArrayKey] = false;
                break;
            }
        }
    }
}
