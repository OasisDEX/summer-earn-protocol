// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ICrossChainRegistry
 * @notice Generic interface for managing cross-chain relationships between different contract types
 * @dev Provides centralized management of cross-chain relationships with support for multiple relationship types
 */
interface ICrossChainRegistry {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents a generic cross-chain relationship between two contracts
     * @param sourceContract The address of the source contract
     * @param targetContract The address of the target contract
     * @param sourceChainId The chain ID where the source contract is deployed
     * @param targetChainId The chain ID where the target contract is deployed
     * @param relationshipType The type of relationship (e.g., keccak256("ARK_FLEET"))
     */
    struct CrossChainRelation {
        address sourceContract;
        address targetContract;
        uint16 sourceChainId;
        uint16 targetChainId;
        bytes32 relationshipType;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a cross-chain relationship is registered
    /// @param sourceContract The address of the source contract
    /// @param targetContract The address of the target contract
    /// @param sourceChainId The chain ID where the source contract is deployed
    /// @param targetChainId The chain ID where the target contract is deployed
    /// @param relationshipType The type of relationship
    event CrossChainRelationshipRegistered(
        address indexed sourceContract,
        address indexed targetContract,
        uint16 indexed sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    );

    /// @notice Emitted when a cross-chain relationship is unregistered
    /// @param sourceContract The address of the source contract
    /// @param targetContract The address of the target contract
    /// @param sourceChainId The chain ID where the source contract was deployed
    /// @param targetChainId The chain ID where the target contract was deployed
    /// @param relationshipType The type of relationship
    event CrossChainRelationshipUnregistered(
        address indexed sourceContract,
        address indexed targetContract,
        uint16 indexed sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to register a relationship that already exists
    error RelationshipAlreadyExists(
        address sourceContract,
        bytes32 relationshipType
    );

    /// @notice Thrown when trying to access a relationship that doesn't exist
    error RelationshipDoesNotExist(
        address sourceContract,
        bytes32 relationshipType
    );

    /// @notice Thrown when an invalid source contract address is provided
    error InvalidSourceContract(address sourceContract);

    /// @notice Thrown when an invalid target contract address is provided
    error InvalidTargetContract(address targetContract);

    /// @notice Thrown when an invalid chain ID is provided
    error InvalidChainId(uint16 chainId);

    /// @notice Thrown when trying to register a same-chain relationship in a cross-chain registry
    error SameChainRelationship(uint16 chainId);

    /// @notice Thrown when neither source nor target chain matches the deployment chain
    error InvalidChainRelationship(
        uint16 sourceChainId,
        uint16 targetChainId,
        uint16 deploymentChainId
    );

    /// @notice Thrown when an invalid relationship type is provided
    error InvalidRelationshipType(bytes32 relationshipType);

    /// @notice Thrown when trying to register a target contract that's already registered to another source contract
    error TargetContractAlreadyRegistered(
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType,
        address existingSourceContract
    );

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new cross-chain relationship
     * @param sourceContract The address of the source contract
     * @param targetContract The address of the target contract
     * @param sourceChainId The chain ID where the source contract is deployed
     * @param targetChainId The chain ID where the target contract is deployed
     * @param relationshipType The type of relationship
     */
    function registerCrossChainRelationship(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external;

    /**
     * @notice Unregister an existing cross-chain relationship
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     */
    function unregisterCrossChainRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external;

    /*//////////////////////////////////////////////////////////////
                            QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the target contract and chain for a given source contract and relationship type
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return targetContract The address of the target contract
     * @return targetChainId The chain ID where the target contract is deployed
     */
    function getTargetForSource(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (address targetContract, uint16 targetChainId);

    /**
     * @notice Get the source contract address for a given target contract and relationship type
     * @param sourceChainId The chain ID of the source chain
     * @param targetChainId The chain ID of the target chain
     * @param targetContract The address of the target contract
     * @param relationshipType The type of relationship
     * @return sourceContract The address of the source contract
     */
    function getSourceForTarget(
        uint16 sourceChainId,
        uint16 targetChainId,
        address targetContract,
        bytes32 relationshipType
    ) external view returns (address sourceContract);

    /**
     * @notice Check if a source-target contract pair is valid for a given relationship type
     * @param sourceContract The address of the source contract
     * @param targetContract The address of the target contract
     * @param sourceChainId The chain ID where the source contract is deployed
     * @param targetChainId The chain ID where the target contract is deployed
     * @param relationshipType The type of relationship
     * @return isValid True if the relationship exists
     */
    function isValidCrossChainPair(
        address sourceContract,
        address targetContract,
        uint16 sourceChainId,
        uint16 targetChainId,
        bytes32 relationshipType
    ) external view returns (bool isValid);

    /**
     * @notice Get the full relationship details
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return relation The complete relationship details
     */
    function getRelationship(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (CrossChainRelation memory relation);

    /*//////////////////////////////////////////////////////////////
                        ENUMERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all registered source contracts for a specific relationship type
     * @param relationshipType The type of relationship
     * @return sourceContracts Array of registered source contract addresses
     */
    function getRegisteredSourceContracts(
        bytes32 relationshipType
    ) external view returns (address[] memory sourceContracts);

    /**
     * @notice Check if a source contract is registered for a specific relationship type
     * @param sourceContract The address of the source contract
     * @param relationshipType The type of relationship
     * @return isRegistered True if the source contract is registered
     */
    function isSourceContractRegistered(
        address sourceContract,
        bytes32 relationshipType
    ) external view returns (bool isRegistered);

    /**
     * @notice Get the total number of registered relationships for a specific type
     * @param relationshipType The type of relationship
     * @return count The number of registered relationships
     */
    function getRelationshipCount(
        bytes32 relationshipType
    ) external view returns (uint256 count);

    /**
     * @notice Get all supported relationship types
     * @return relationshipTypes Array of supported relationship type hashes
     */
    function getSupportedRelationshipTypes()
        external
        view
        returns (bytes32[] memory relationshipTypes);

    /**
     * @notice Get the current chain ID
     * @return The current chain ID
     */
    function currentChainId() external view returns (uint16);
}
