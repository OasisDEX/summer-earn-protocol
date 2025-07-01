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

    /// @notice Mapping from crossChainArk address to relationship information
    mapping(address => CrossChainArkFleetProxyRelation)
        private crossChainArkToFleetProxy;

    /// @notice Mapping from keccak256(abi.encode(sourceChainId, fleetProxy)) to crossChainArk address
    mapping(bytes32 => address) private fleetProxyToCrossChainArk;

    /// @notice Array of all registered crossChainArk addresses for enumeration
    address[] private registeredCrossChainArks;

    /// @notice Mapping to track if a crossChainArk is registered (for gas optimization)
    mapping(address => bool) private crossChainArkRegistered;

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
    function registerCrossChainArkFleetProxy(
        address crossChainArk,
        uint16 sourceChainId,
        uint16 targetChainId,
        address fleetProxy
    ) external override onlyGovernor {
        if (crossChainArk == address(0))
            revert InvalidCrossChainArk(crossChainArk);
        if (fleetProxy == address(0)) revert InvalidFleetProxy(fleetProxy);
        if (sourceChainId == 0) revert InvalidChainId(sourceChainId);
        if (targetChainId == 0) revert InvalidChainId(targetChainId);

        // This function can be called on either source or target chain
        // Source chain: Allows CrossChainArk to find its target fleetProxy
        // Target chain: Allows FleetProxy to validate source crossChainArk relationships

        // Check if crossChainArk already exists (using crossChainArk address as unique identifier)
        if (crossChainArkRegistered[crossChainArk]) {
            revert RelationshipAlreadyExists(
                crossChainArk,
                sourceChainId,
                fleetProxy
            );
        }

        // Check if this fleetProxy is already registered to another crossChainArk (for target chain lookups)
        bytes32 fleetProxyKey = keccak256(
            abi.encode(sourceChainId, fleetProxy)
        );
        if (fleetProxyToCrossChainArk[fleetProxyKey] != address(0)) {
            revert FleetProxyAlreadyRegistered(
                fleetProxy,
                sourceChainId,
                fleetProxyToCrossChainArk[fleetProxyKey]
            );
        }

        // Create the relationship
        crossChainArkToFleetProxy[
            crossChainArk
        ] = CrossChainArkFleetProxyRelation({
            fleetProxy: fleetProxy,
            targetChainId: targetChainId, // Explicit target chain ID
            sourceChainId: sourceChainId, // Explicit source chain ID
            isActive: true // Default to active
        });

        // Set reverse mapping: (sourceChainId, fleetProxy) -> crossChainArk (used by target chain FleetProxy)
        fleetProxyToCrossChainArk[fleetProxyKey] = crossChainArk;

        // Update tracking
        registeredCrossChainArks.push(crossChainArk);
        crossChainArkRegistered[crossChainArk] = true;

        emit CrossChainArkFleetProxyRegistered(
            crossChainArk,
            sourceChainId,
            fleetProxy
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function unregisterCrossChainArkFleetProxy(
        address crossChainArk
    ) external override onlyGovernor {
        if (!crossChainArkRegistered[crossChainArk]) {
            revert RelationshipDoesNotExist(crossChainArk);
        }

        CrossChainArkFleetProxyRelation
            memory relation = crossChainArkToFleetProxy[crossChainArk];

        // Remove reverse mapping using the stored sourceChainId
        bytes32 fleetProxyKey = keccak256(
            abi.encode(relation.sourceChainId, relation.fleetProxy)
        );
        delete fleetProxyToCrossChainArk[fleetProxyKey];

        // Remove from registered crossChainArks array
        for (uint256 i = 0; i < registeredCrossChainArks.length; i++) {
            if (registeredCrossChainArks[i] == crossChainArk) {
                registeredCrossChainArks[i] = registeredCrossChainArks[
                    registeredCrossChainArks.length - 1
                ];
                registeredCrossChainArks.pop();
                break;
            }
        }

        // Clean up mappings
        delete crossChainArkToFleetProxy[crossChainArk];
        delete crossChainArkRegistered[crossChainArk];

        emit CrossChainArkFleetProxyUnregistered(
            crossChainArk,
            relation.sourceChainId,
            relation.fleetProxy
        );
    }

    /// @inheritdoc ICrossChainRegistry
    function updateRelationshipStatus(
        address crossChainArk,
        bool isActive
    ) external override onlyGovernor {
        if (!crossChainArkRegistered[crossChainArk]) {
            revert RelationshipDoesNotExist(crossChainArk);
        }

        crossChainArkToFleetProxy[crossChainArk].isActive = isActive;
        emit RelationshipStatusUpdated(crossChainArk, isActive);
    }

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getFleetProxyForCrossChainArk(
        address crossChainArk
    )
        external
        view
        override
        returns (address fleetProxy, uint16 targetChainId)
    {
        if (!crossChainArkRegistered[crossChainArk]) {
            revert RelationshipDoesNotExist(crossChainArk);
        }

        CrossChainArkFleetProxyRelation
            memory relation = crossChainArkToFleetProxy[crossChainArk];
        return (relation.fleetProxy, relation.targetChainId);
    }

    /// @inheritdoc ICrossChainRegistry
    function getCrossChainArkForFleetProxy(
        uint16 sourceChainId,
        address fleetProxy
    ) external view override returns (address crossChainArk) {
        bytes32 fleetProxyKey = keccak256(
            abi.encode(sourceChainId, fleetProxy)
        );
        crossChainArk = fleetProxyToCrossChainArk[fleetProxyKey];
        if (crossChainArk == address(0)) {
            revert RelationshipDoesNotExist(fleetProxy);
        }
    }

    /// @inheritdoc ICrossChainRegistry
    function isValidCrossChainArkFleetProxyPair(
        address crossChainArk,
        uint16 sourceChainId,
        address fleetProxy
    ) external view override returns (bool isValid) {
        if (!crossChainArkRegistered[crossChainArk]) {
            return false;
        }

        CrossChainArkFleetProxyRelation
            memory relation = crossChainArkToFleetProxy[crossChainArk];
        return (relation.fleetProxy == fleetProxy &&
            relation.sourceChainId == sourceChainId &&
            relation.isActive);
    }

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainRegistry
    function getRegisteredCrossChainArks()
        external
        view
        override
        returns (address[] memory crossChainArks)
    {
        return registeredCrossChainArks;
    }

    /// @inheritdoc ICrossChainRegistry
    function isCrossChainArkRegistered(
        address crossChainArk
    ) external view override returns (bool isRegistered) {
        return crossChainArkRegistered[crossChainArk];
    }

    /// @inheritdoc ICrossChainRegistry
    function getRelationshipCount()
        external
        view
        override
        returns (uint256 count)
    {
        return registeredCrossChainArks.length;
    }
}
