// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title CrossChainRegistry
 * @notice Simplified centralized registry for managing cross-chain relationships between CrossChainArk and FleetProxy contracts
 * @dev Inherits from ProtocolAccessManaged for access control and implements ICrossChainRegistry with core functionality only
 */
contract CrossChainRegistry is ICrossChainRegistry, ProtocolAccessManaged {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The chain ID of the current deployment
    uint16 public immutable currentChainId;

    /// @notice Mapping from ark address to relationship information
    mapping(address => ArkProxyRelation) private arkToProxy;

    /// @notice Mapping from keccak256(abi.encode(sourceChainId, proxy)) to ark address
    mapping(bytes32 => address) private proxyToArk;

    /// @notice Array of all registered ark addresses for enumeration
    address[] private registeredArks;

    /// @notice Mapping to track if an ark is registered (for gas optimization)
    mapping(address => bool) private arkRegistered;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the registry is initialized
    event RegistryInitialized(uint16 currentChainId);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the current chain ID is zero
    error InvalidCurrentChainId();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainRegistry
     * @param _accessManager Address of the access manager
     * @param _currentChainId The chain ID of the current deployment
     */
    constructor(
        address _accessManager,
        uint16 _currentChainId
    ) ProtocolAccessManaged(_accessManager) {
        if (_currentChainId == 0) revert InvalidCurrentChainId();

        currentChainId = _currentChainId;
        emit RegistryInitialized(_currentChainId);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function registerArkProxy(
        address ark,
        uint16 targetChainId,
        address proxy
    ) external override onlyGovernor {
        if (ark == address(0)) revert InvalidArk(ark);
        if (proxy == address(0)) revert InvalidProxy(proxy);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);

        // Check if ark already exists
        if (arkRegistered[ark]) {
            revert RelationshipAlreadyExists(ark, targetChainId, proxy);
        }

        // Check if proxy is already registered to another ark
        bytes32 proxyKey = keccak256(abi.encode(currentChainId, proxy));
        if (proxyToArk[proxyKey] != address(0)) {
            revert ProxyAlreadyRegistered(
                proxy,
                currentChainId,
                proxyToArk[proxyKey]
            );
        }

        // Create the relationship
        arkToProxy[ark] = ArkProxyRelation({
            proxy: proxy,
            targetChainId: targetChainId,
            isActive: true // Default to active
        });

        // Set reverse mapping
        proxyToArk[proxyKey] = ark;

        // Update tracking
        registeredArks.push(ark);
        arkRegistered[ark] = true;

        emit ArkProxyRegistered(ark, targetChainId, proxy);
    }

    /// @inheritdoc ICrossChainRegistry
    function unregisterArkProxy(address ark) external override onlyGovernor {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        ArkProxyRelation memory relation = arkToProxy[ark];

        // Remove reverse mapping
        bytes32 proxyKey = keccak256(
            abi.encode(currentChainId, relation.proxy)
        );
        delete proxyToArk[proxyKey];

        // Remove from registered arks array
        for (uint256 i = 0; i < registeredArks.length; i++) {
            if (registeredArks[i] == ark) {
                registeredArks[i] = registeredArks[registeredArks.length - 1];
                registeredArks.pop();
                break;
            }
        }

        // Clean up mappings
        delete arkToProxy[ark];
        delete arkRegistered[ark];

        emit ArkProxyUnregistered(ark, relation.targetChainId, relation.proxy);
    }

    /// @inheritdoc ICrossChainRegistry
    function updateRelationshipStatus(
        address ark,
        bool isActive
    ) external override onlyGovernor {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        arkToProxy[ark].isActive = isActive;
        emit RelationshipStatusUpdated(ark, isActive);
    }

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getProxyForArk(
        address ark
    ) external view override returns (address proxy, uint16 targetChainId) {
        if (!arkRegistered[ark]) {
            revert RelationshipDoesNotExist(ark);
        }

        ArkProxyRelation memory relation = arkToProxy[ark];
        return (relation.proxy, relation.targetChainId);
    }

    /// @inheritdoc ICrossChainRegistry
    function getArkForProxy(
        uint16 sourceChainId,
        address proxy
    ) external view override returns (address ark) {
        bytes32 proxyKey = keccak256(abi.encode(sourceChainId, proxy));
        ark = proxyToArk[proxyKey];
        if (ark == address(0)) {
            revert RelationshipDoesNotExist(proxy);
        }
    }

    /// @inheritdoc ICrossChainRegistry
    function isValidArkProxyPair(
        address ark,
        uint16 targetChainId,
        address proxy
    ) external view override returns (bool isValid) {
        if (!arkRegistered[ark]) {
            return false;
        }

        ArkProxyRelation memory relation = arkToProxy[ark];
        return (relation.proxy == proxy &&
            relation.targetChainId == targetChainId &&
            relation.isActive);
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredArks()
        external
        view
        override
        returns (address[] memory arks)
    {
        return registeredArks;
    }

    /// @inheritdoc ICrossChainRegistry
    function isArkRegistered(
        address ark
    ) external view override returns (bool isRegistered) {
        return arkRegistered[ark];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount()
        external
        view
        override
        returns (uint256 count)
    {
        return registeredArks.length;
    }
}
