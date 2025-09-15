// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {CrossChainConfigManaged} from "../contracts/CrossChainConfigManaged.sol";
/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters.
 *      Operations can only be initiated via the authorized executor or governance.
 */
contract BridgeRouter is
    IBridgeRouter,
    ProtocolAccessManaged,
    ReentrancyGuard,
    Nonces,
    CrossChainConfigManaged
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Set of registered adapters
    EnumerableSet.AddressSet private adapters;

    /// @notice Mapping of operation IDs to the adapter that processed them
    mapping(bytes32 operationId => address adapterAddress)
        public operationToAdapter;

    /// @notice Mapping to track read request originators
    mapping(bytes32 requestId => address originator)
        public readRequestToOriginator;

    /// @notice Pause state of the router
    bool public paused;

    /// @notice Record of failed delivery attempts by operationId
    struct FailedDeliveryRecord {
        BridgeTypes.OperationType operationType;
        address adapter;
        uint16 sourceChainId;
        bytes operationPayload; // original encoded payload
        uint256 failedAt; // block timestamp
    }

    /// @notice Optional overrides when retrying a failed delivery
    struct RetryOverrideParams {
        address recipient; // set to address(0) to keep stored recipient
        address asset; // set to address(0) to keep stored asset, or override with actual received asset
        // Note: Adapters typically override asset addresses for cross-chain compatibility,
        // but this allows manual override if needed for edge cases
    }

    /// @notice Mapping from operationId to failure record (exists if failed)
    mapping(bytes32 operationId => FailedDeliveryRecord record)
        public failedDeliveries;

    /// @notice Set of failed operationIds for enumeration/pagination
    EnumerableSet.Bytes32Set private failedDeliveryIds;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BridgeRouter contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @param _registry Address of the CrossChainRegistry contract
     */
    constructor(
        address accessManager,
        address _registry
    ) ProtocolAccessManaged(accessManager) CrossChainConfigManaged(_registry) {}

    /*//////////////////////////////////////////////////////////////
                        MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier ensuring the caller (`msg.sender`) is a registered adapter.
     * Reverts with `UnknownAdapter` if the caller is not in the `adapters` set.
     */
    modifier onlyRegisteredAdapter() {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
        _;
    }

    /**
     * @dev Modifier ensuring the contract is not paused.
     * Reverts with `Paused` if the contract is in the paused state.
     */
    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    /**
     * @dev Modifier ensuring the adapter is valid and supports the operation type.
     * Reverts with `UnknownAdapter` if the adapter is not valid.
     * Reverts with `UnsupportedAdapterOperation` if the adapter does not support the operation type.
     */
    modifier validAdapter(
        address adapter,
        BridgeTypes.OperationType operationType
    ) {
        if (!this.isValidAdapter(adapter)) revert UnknownAdapter();
        _validateAdapterSupportsOperation(adapter, operationType);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    ADAPTER PEER RELATIONSHIP CHECK
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Asserts that a peer mapping exists in the registry for `(sourceChainId, msg.sender)`.
     * @param sourceChainId The source chain ID from the cross-chain operation
     *
     * NOTE: This only verifies that governance has registered a peer relationship for the
     *       calling adapter on the given source chain. It does NOT authenticate the
     *       specific source adapter that originated the packet. Identity binding is enforced
     *       within adapters using bridge-native metadata (e.g. LayerZero Origin.sender, Taxi srcSender)
     *       via the registry's `isValidAdapterPeer` checks.
     */
    function _assertPeerMappingExistsForChain(
        uint16 sourceChainId
    ) internal view {
        // Will revert if (srcChainId, msg.sender) is NOT a registered pair
        CROSS_CHAIN_REGISTRY.getSourceForTarget(
            sourceChainId,
            uint16(block.chainid),
            msg.sender,
            CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
        );
    }

    /**
     * @dev Variant that verifies a peer mapping for an explicit adapter address.
     *      Used when processing deliveries via self-call where msg.sender == address(this).
     */
    function _assertPeerMappingExistsForChainFromAdapter(
        uint16 sourceChainId,
        address adapter
    ) internal view {
        CROSS_CHAIN_REGISTRY.getSourceForTarget(
            sourceChainId,
            uint16(block.chainid),
            adapter,
            CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
        );
    }

    /*//////////////////////////////////////////////////////////////
                       INTERNAL UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to validate transfer parameters
     * @param params Parameters to validate
     */
    function _validateTransferParams(
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal pure {
        if (
            params.amount == 0 ||
            params.target == address(0) ||
            params.originator == address(0) ||
            params.asset == address(0) ||
            params.refundAddress == address(0) ||
            params.destinationChainId == 0
        ) revert InvalidParams();
    }

    /**
     * @dev Internal function to validate read state parameters
     * @param params Parameters to validate
     */
    function _validateReadStateParams(
        BridgeTypes.ExecuteReadStateParams calldata params
    ) internal pure {
        if (
            params.originator == address(0) ||
            params.target == address(0) ||
            params.destinationChainId == 0 ||
            params.selector == bytes4(0) ||
            params.refundAddress == address(0)
        ) revert InvalidParams();
    }

    /**
     * @dev Internal function to validate send message parameters
     * @param params Parameters to validate
     */
    function _validateSendMessageParams(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) internal pure {
        if (
            params.target == address(0) ||
            params.originator == address(0) ||
            params.destinationChainId == 0 ||
            params.refundAddress == address(0) ||
            params.message.length == 0
        ) {
            revert InvalidParams();
        }
    }

    function _validateOriginator(address originator) internal view {
        if (originator != msg.sender) revert InvalidOriginator();
    }

    /**
     * @dev Internal function to validate if an adapter supports a specific operation type
     * @param adapter The adapter address to validate
     * @param operationType The type of operation to check support for
     */
    function _validateAdapterSupportsOperation(
        address adapter,
        BridgeTypes.OperationType operationType
    ) internal view {
        if (adapter == address(0)) revert NoSuitableAdapter();
        if (!IBridgeAdapter(adapter).supportsOperation(operationType)) {
            revert UnsupportedAdapterOperation();
        }
    }

    /**
     * @dev Internal function to generate a unique operation ID and set initial status
     * @param operationType Type of operation being performed
     * @param destinationChainId Target chain ID
     * @param asset Asset address (address(0) for non-asset operations)
     * @param amount Amount (0 for non-asset operations)
     * @param target Recipient address
     * @param additionalData Additional data for ID generation (contract address, selector, etc.)
     * @return operationId The generated operation ID
     */
    function _generateOperationId(
        BridgeTypes.OperationType operationType,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address target,
        bytes memory additionalData
    ) internal returns (bytes32 operationId) {
        // Use nonce for better uniqueness and collision resistance
        uint256 currentNonce = _useNonce(address(this));

        operationId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainId,
                asset,
                amount,
                target,
                additionalData,
                currentNonce,
                operationType
            )
        );

        return operationId;
    }

    /**
     * @dev Internal function to apply fee buffer for cross-chain operation volatility
     * @param baseFee The base fee amount to buffer
     * @return bufferedFee The fee with 1% buffer applied
     */
    function _applyFeeBuffer(
        uint256 baseFee
    ) internal pure returns (uint256 bufferedFee) {
        // Add 1% buffer to account for fee volatility
        return (baseFee * 101) / 100;
    }

    /*//////////////////////////////////////////////////////////////
                      FAILURE RECORDING UTILITIES
    //////////////////////////////////////////////////////////////*/

    function _recordFailedDelivery(
        bytes32 operationId,
        BridgeTypes.OperationType operationType,
        address adapter,
        uint16 sourceChainId,
        bytes memory operationPayload,
        bytes memory errorData
    ) internal {
        FailedDeliveryRecord storage existing = failedDeliveries[operationId];
        if (existing.failedAt == 0) {
            // Insert new record
            failedDeliveries[operationId] = FailedDeliveryRecord({
                operationType: operationType,
                adapter: adapter,
                sourceChainId: sourceChainId,
                operationPayload: operationPayload,
                failedAt: block.timestamp
            });
            failedDeliveryIds.add(operationId);
        } else {
            // Update existing record
            existing.failedAt = block.timestamp;
            // Keep original payload and metadata
        }

        emit OperationFailed(
            operationId,
            operationType,
            adapter,
            sourceChainId,
            errorData
        );
    }

    function _clearFailedDelivery(bytes32 operationId) internal {
        failedDeliveryIds.remove(operationId);
        delete failedDeliveries[operationId];
    }

    function _decodeOperationMeta(
        BridgeTypes.OperationType operationType,
        bytes memory operationPayload
    ) internal pure returns (bytes32 opId, uint16 sourceChainId) {
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory d = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedTransferParams)
            );
            return (d.operationId, d.sourceChainId);
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory d = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedMessageParams)
            );
            return (d.operationId, d.sourceChainId);
        } else if (operationType == BridgeTypes.OperationType.READ_STATE) {
            BridgeTypes.RelayedReadResponse memory d = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedReadResponse)
            );
            return (d.operationId, d.sourceChainId);
        } else {
            revert UnsupportedOperationType();
        }
    }

    /*//////////////////////////////////////////////////////////////
                           BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        )
        returns (bytes32 operationId)
    {
        if (options.gasLimit == 0) revert ZeroGasLimit();
        _validateTransferParams(params);
        _validateOriginator(params.originator);

        address specifiedAdapter = options.specifiedAdapter;

        // Pull tokens from authorized executor to Router first
        IERC20(params.asset).safeTransferFrom(
            msg.sender, // authorized executor approved us
            address(this), // Transfer to Router
            params.amount
        );

        // Now approve the adapter to spend Router's tokens
        IERC20(params.asset).forceApprove(specifiedAdapter, params.amount);

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target,
            abi.encode(params.originator) // Additional data for uniqueness
        );

        // Call adapter with the full msg.value
        IAssetAdapter(specifiedAdapter).transferAsset{value: msg.value}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.target,
            specifiedAdapter
        );

        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.READ_STATE
        )
        returns (bytes32 operationId)
    {
        if (options.gasLimit == 0) revert ZeroGasLimit();
        _validateReadStateParams(params);
        _validateOriginator(params.originator);

        address specifiedAdapter = options.specifiedAdapter;

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.READ_STATE,
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            address(0), // No target for read operations
            abi.encode(
                params.target,
                params.selector,
                params.readParams,
                params.originator
            )
        );

        // Only relevant for read operations
        operationToAdapter[operationId] = specifiedAdapter;

        // Store the originator for response delivery
        readRequestToOriginator[operationId] = params.originator;

        // Call adapter with the full msg.value
        IMessageAdapter(specifiedAdapter).readState{value: msg.value}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

        emit ReadRequestInitiated(
            operationId,
            params.destinationChainId,
            params.target,
            params.selector,
            params.readParams,
            specifiedAdapter
        );

        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        payable
        onlyAuthorizedExecutor
        whenNotPaused
        nonReentrant
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.MESSAGE
        )
        returns (bytes32 operationId)
    {
        if (options.gasLimit == 0) revert ZeroGasLimit();
        _validateSendMessageParams(params);
        _validateOriginator(params.originator);

        address specifiedAdapter = options.specifiedAdapter;

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.MESSAGE,
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            params.target,
            abi.encode(params.message, params.originator)
        );

        // Call adapter with the full msg.value
        IMessageAdapter(specifiedAdapter).sendMessage{value: msg.value}(
            operationId, // Pass the router-generated ID
            params,
            options
        );

        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.target,
            specifiedAdapter
        );

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.OperationType operationType
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;

        if (specifiedAdapter == address(0)) revert NoSuitableAdapter();
        if (!this.isValidAdapter(specifiedAdapter)) revert UnknownAdapter();
        if (options.gasLimit == 0) revert ZeroGasLimit();

        (nativeFee, tokenFee) = IBridgeAdapter(specifiedAdapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options,
            operationType
        );

        nativeFee = _applyFeeBuffer(nativeFee);
        tokenFee = _applyFeeBuffer(tokenFee);

        return (nativeFee, tokenFee, specifiedAdapter);
    }

    /// @inheritdoc IBridgeRouter
    function deliver(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload
    ) external onlyRegisteredAdapter nonReentrant {
        // Pre-decode minimal fields for logging/recording
        (bytes32 operationId, uint16 sourceChainId) = _decodeOperationMeta(
            operationType,
            operationPayload
        );

        // Attempt processing in a self-call so we can capture reverts without
        // rolling back the outer call (adapter delivery pathway)
        try this._processDelivery(operationType, operationPayload, msg.sender) {
            // Success path
            // If there was a stale failure record (edge-case), clear it
            _clearFailedDelivery(operationId);
            emit OperationDelivered(operationId, operationType);
        } catch (bytes memory err) {
            _recordFailedDelivery(
                operationId,
                operationType,
                msg.sender,
                sourceChainId,
                operationPayload,
                err
            );
            // Do not revert; adapter can mark as delivered on-chain while we recorded failure
        }
    }

    /**
     * @notice Internal processing of a delivery wrapped in a self-call for atomicity.
     * @dev MUST only be invoked by this contract via `this._processDelivery(...)`.
     */
    function _processDelivery(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload,
        address adapter
    ) external {
        if (msg.sender != address(this)) revert Unauthorized();

        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            // Verify adapter has peer relationship with source chain
            _assertPeerMappingExistsForChainFromAdapter(
                data.sourceChainId,
                adapter
            );

            // Transfer the asset and then notify the receiver
            IERC20(data.asset).safeTransfer(data.recipient, data.amount);

            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                operationPayload
            );
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedMessageParams)
            );

            // Verify adapter has peer relationship with source chain
            _assertPeerMappingExistsForChainFromAdapter(
                data.sourceChainId,
                adapter
            );

            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.MESSAGE,
                operationPayload
            );
        } else if (operationType == BridgeTypes.OperationType.READ_STATE) {
            BridgeTypes.RelayedReadResponse memory data = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedReadResponse)
            );

            // Authorization: ensure the responding adapter matches the one that originated the read
            if (operationToAdapter[data.operationId] != adapter)
                revert Unauthorized();

            address originator = readRequestToOriginator[data.operationId];
            if (originator == address(0)) revert InvalidParams();

            ICrossChainReceiver(originator).receiveOperation(
                BridgeTypes.OperationType.READ_STATE,
                operationPayload
            );
        } else {
            revert UnsupportedOperationType();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function getAdapters() public view returns (address[] memory) {
        return adapters.values();
    }

    /// @inheritdoc IBridgeRouter
    function isValidAdapter(address adapter) external view returns (bool) {
        return adapters.contains(adapter);
    }

    /*//////////////////////////////////////////////////////////////
                          FAILURE VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a page of failed delivery operationIds
    function getFailedDeliveryIds(
        uint256 cursor,
        uint256 size
    ) external view returns (bytes32[] memory ids, uint256 nextCursor) {
        uint256 len = failedDeliveryIds.length();
        if (cursor >= len) {
            return (new bytes32[](0), cursor);
        }
        uint256 end = cursor + size;
        if (end > len) end = len;
        uint256 pageSize = end - cursor;
        ids = new bytes32[](pageSize);
        for (uint256 i = 0; i < pageSize; i++) {
            ids[i] = failedDeliveryIds.at(cursor + i);
        }
        nextCursor = end;
    }

    /// @notice Returns the failure record for an operationId (reverts if none)
    function getFailedDelivery(
        bytes32 operationId
    ) external view returns (FailedDeliveryRecord memory) {
        FailedDeliveryRecord memory r = failedDeliveries[operationId];
        if (r.failedAt == 0) revert FailureRecordNotFound();
        return r;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function registerAdapter(address adapter) external onlyGovernor {
        if (adapters.contains(adapter)) revert AdapterAlreadyRegistered();

        adapters.add(adapter);
        emit AdapterRegistered(adapter);
    }

    /// @inheritdoc IBridgeRouter
    function removeAdapter(address adapter) external onlyGovernor {
        if (!adapters.contains(adapter)) revert UnknownAdapter();

        adapters.remove(adapter);
        emit AdapterRemoved(adapter);
    }

    /// @inheritdoc IBridgeRouter
    function pause() external onlyGuardianOrGovernor {
        paused = true;
    }

    /// @inheritdoc IBridgeRouter
    function unpause() external onlyGovernor {
        paused = false;
    }

    /// @inheritdoc IBridgeRouter
    function sweep(
        address token,
        address recipient,
        uint256 amount
    ) external nonReentrant onlyGovernor {
        if (recipient == address(0)) revert InvalidParams();

        if (token == address(0)) {
            // Recover native ETH
            if (address(this).balance < amount) revert InsufficientBalance();
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Recover ERC20 using SafeERC20
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit RouterAssetsRecovered(token, recipient, amount);
    }

    /// @notice Retries a previously failed delivery with optional overrides. Only callable by governor.
    /// @param operationId The failed operation identifier
    /// @param overrideData ABI-encoded RetryOverrideParams; pass empty to use stored values
    function retryFailedDelivery(
        bytes32 operationId,
        bytes calldata overrideData
    ) external nonReentrant onlyGovernor whenNotPaused {
        FailedDeliveryRecord memory r = failedDeliveries[operationId];

        if (r.failedAt == 0) revert InvalidParams();

        // State reads should not be retryable as they are read-only operations
        if (r.operationType == BridgeTypes.OperationType.READ_STATE) {
            revert UnsupportedOperationType();
        }

        // Use the original adapter - no override needed
        address effectiveAdapter = r.adapter;

        // Decode the original payload
        bytes memory effectivePayload = r.operationPayload;

        // Apply overrides if provided
        if (overrideData.length > 0) {
            RetryOverrideParams memory overrides = abi.decode(
                overrideData,
                (RetryOverrideParams)
            );

            // Apply overrides to the payload
            effectivePayload = _applyRetryOverrides(
                r.operationType,
                effectivePayload,
                overrides
            );
        }

        // Validate that payload decodes and carries the same operationId and sourceChainId
        (bytes32 decodedId, uint16 sourceChainId) = _decodeOperationMeta(
            r.operationType,
            effectivePayload
        );
        if (decodedId != operationId) revert InvalidParams();
        if (sourceChainId != r.sourceChainId) revert InvalidParams();

        // Enhanced payload validation
        _validateRetryPayload(
            r.operationType,
            effectivePayload,
            r.sourceChainId,
            effectiveAdapter
        );

        try
            this._processDelivery(
                r.operationType,
                effectivePayload,
                effectiveAdapter
            )
        {
            _clearFailedDelivery(operationId);
            emit OperationRetrySucceeded(
                operationId,
                r.operationType,
                effectiveAdapter
            );
        } catch (bytes memory err) {
            // Do not create a new failure record; update existing metadata only
            FailedDeliveryRecord storage existing = failedDeliveries[
                operationId
            ];
            existing.failedAt = block.timestamp;

            emit OperationRetryFailed(
                operationId,
                r.operationType,
                effectiveAdapter,
                err
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                        RETRY OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Applies retry overrides to the operation payload
     * @param operationType Type of operation being retried
     * @param originalPayload The original payload
     * @param overrides The override parameters
     * @return modifiedPayload The payload with overrides applied
     */
    function _applyRetryOverrides(
        BridgeTypes.OperationType operationType,
        bytes memory originalPayload,
        RetryOverrideParams memory overrides
    ) internal pure returns (bytes memory modifiedPayload) {
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            // Apply recipient override
            if (overrides.recipient != address(0)) {
                params.recipient = overrides.recipient;
            }

            // CRITICAL: Apply asset override for cross-chain operations
            // This fixes the asset address mismatch issue where the original payload
            // contains the source chain asset address, but the BridgeRouter actually
            // holds the target chain asset address after adapter processing.
            if (overrides.asset != address(0)) {
                params.asset = overrides.asset;
            }

            return abi.encode(params);
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedMessageParams)
            );

            // Apply recipient override
            if (overrides.recipient != address(0)) {
                params.recipient = overrides.recipient;
            }

            return abi.encode(params);
        } else {
            // For unsupported operation types, return original payload
            return originalPayload;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PAYLOAD VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates retry payload integrity and system state
     * @param operationType Type of operation being retried
     * @param payload The payload to validate
     * @param sourceChainId Expected source chain ID
     * @param adapter The adapter that will process the retry
     */
    function _validateRetryPayload(
        BridgeTypes.OperationType operationType,
        bytes memory payload,
        uint16 sourceChainId,
        address adapter
    ) internal view {
        // Validate payload integrity based on operation type
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            _validateTransferPayload(payload, sourceChainId, adapter);
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            _validateMessagePayload(payload, sourceChainId, adapter);
        }
    }

    /**
     * @notice Validates transfer asset payload integrity
     * @param payload The transfer payload to validate
     * @param sourceChainId Expected source chain ID
     * @param adapter The adapter that will process the retry
     */
    function _validateTransferPayload(
        bytes memory payload,
        uint16 sourceChainId,
        address adapter
    ) internal view {
        BridgeTypes.RelayedTransferParams memory params = abi.decode(
            payload,
            (BridgeTypes.RelayedTransferParams)
        );

        // Validate ark-fleet relationship in both directions
        _validateArkFleetRelationship(
            params.originator,
            params.recipient,
            sourceChainId
        );

        // Validate asset is still supported and sufficient amount is available
        _validateAssetStillSupported(params.asset, params.amount);
    }

    /**
     * @notice Validates message payload integrity
     * @param payload The message payload to validate
     * @param sourceChainId Expected source chain ID
     * @param adapter The adapter that will process the retry
     */
    function _validateMessagePayload(
        bytes memory payload,
        uint16 sourceChainId,
        address adapter
    ) internal view {
        BridgeTypes.RelayedMessageParams memory params = abi.decode(
            payload,
            (BridgeTypes.RelayedMessageParams)
        );

        // Validate ark-fleet relationship in both directions
        _validateArkFleetRelationship(
            params.originator,
            params.recipient,
            sourceChainId
        );
    }

    /**
     * @notice Validates that ark-fleet relationship is valid in both directions
     * @param originator The originator address (fleet)
     * @param recipient The recipient address (ark)
     * @param sourceChainId The source chain ID
     */
    function _validateArkFleetRelationship(
        address originator,
        address recipient,
        uint16 sourceChainId
    ) internal view {
        // Check if recipient is a registered ark proxy
        bool isArkProxy = CROSS_CHAIN_REGISTRY.isSourceContractRegistered(
            recipient,
            CROSS_CHAIN_REGISTRY.ARK_FLEET_RELATIONSHIP()
        );

        if (isArkProxy) {
            // Validate ark -> fleet relationship (recipient -> originator)
            (address expectedFleet, ) = CROSS_CHAIN_REGISTRY.getTargetForSource(
                recipient,
                CROSS_CHAIN_REGISTRY.ARK_FLEET_RELATIONSHIP()
            );
            if (expectedFleet != originator) {
                revert InvalidRecipient();
            }

            // Validate fleet -> ark relationship (originator -> recipient) using cross-chain pair validation
            bool isValidPair = CROSS_CHAIN_REGISTRY.isValidCrossChainPair(
                originator,
                recipient,
                sourceChainId,
                uint16(block.chainid),
                CROSS_CHAIN_REGISTRY.ARK_FLEET_RELATIONSHIP()
            );

            if (!isValidPair) {
                revert InvalidRecipient();
            }
        }
        // If recipient is not an ark proxy, we allow the operation to proceed
        // This maintains backward compatibility and allows for non-ark recipients
    }

    /**
     * @notice Validates that the required amount of assets is available for retry
     * @param asset The asset address to validate
     * @param amount The amount of assets required for the retry
     */
    function _validateAssetStillSupported(
        address asset,
        uint256 amount
    ) internal view {
        // Check if the router has sufficient balance of the asset for the retry
        // This is critical because after a failed delivery, assets should remain in the router
        uint256 routerBalance = IERC20(asset).balanceOf(address(this));
        if (routerBalance < amount) {
            revert InsufficientBalance();
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return (interfaceId == type(IBridgeRouter).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }
}
