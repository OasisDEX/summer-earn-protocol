// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";

import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {IMessageAdapter} from "../interfaces/IMessageAdapter.sol";
import {IAssetAdapter} from "../interfaces/IAssetAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
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
        // If no adapter specified, surface a dedicated error
        if (adapter == address(0)) revert NoSuitableAdapter();
        if (!adapters.contains(adapter)) revert UnknownAdapter();
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

    /**
     * @dev Ensures `receiver` is a contract that supports `ICrossChainReceiver` via ERC165
     *      Reverts with `InvalidParams` otherwise.
     * @param receiver The address to validate
     */
    function _requireReceiverIsCrossChainReceiver(
        address receiver
    ) internal view {
        if (receiver.code.length == 0) revert InvalidParams();
        try
            IERC165(receiver).supportsInterface(
                type(ICrossChainReceiver).interfaceId
            )
        returns (bool isSupported) {
            if (!isSupported) revert InvalidParams();
        } catch {
            revert InvalidParams();
        }
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
    function quoteTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        validAdapter(
            options.specifiedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        )
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;

        if (options.gasLimit == 0) revert ZeroGasLimit();

        _validateTransferParams(params);
        (nativeFee, tokenFee) = IBridgeAdapter(specifiedAdapter)
            .estimateTransferAssets(params, options);

        nativeFee = _applyFeeBuffer(nativeFee);
        tokenFee = _applyFeeBuffer(tokenFee);
    }

    /// @inheritdoc IBridgeRouter
    function quoteReadState(
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;
        if (specifiedAdapter == address(0)) revert NoSuitableAdapter();
        if (!adapters.contains(specifiedAdapter)) revert UnknownAdapter();

        _validateReadStateParams(params);
        (nativeFee, tokenFee) = IBridgeAdapter(specifiedAdapter)
            .estimateReadState(params, options);

        nativeFee = _applyFeeBuffer(nativeFee);
        tokenFee = _applyFeeBuffer(tokenFee);
    }

    /// @inheritdoc IBridgeRouter
    function quoteSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;
        if (specifiedAdapter == address(0)) revert NoSuitableAdapter();
        if (!adapters.contains(specifiedAdapter)) revert UnknownAdapter();

        _validateSendMessageParams(params);
        (nativeFee, tokenFee) = IBridgeAdapter(specifiedAdapter)
            .estimateSendMessage(params, options);

        nativeFee = _applyFeeBuffer(nativeFee);
        tokenFee = _applyFeeBuffer(tokenFee);
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
            // Success path - clear any existing failure record for this operation
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
            // Do not revert; from the interchain messaging protocol perspective, the transaction is considered successful even if delivery failed here
            // This allows us to retry failed deliveries without trapping a message with the underlying interchain messaging protocol
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

            // Require recipient is a contract and supports ICrossChainReceiver
            _requireReceiverIsCrossChainReceiver(data.recipient);

            // Transfer the asset
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

            // Require recipient is a contract and supports ICrossChainReceiver
            _requireReceiverIsCrossChainReceiver(data.recipient);

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
            // For read responses, deliver to originator (must be contract implementing interface)
            _requireReceiverIsCrossChainReceiver(originator);

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
        if (adapter == address(0)) revert InvalidParams();
        if (adapter.code.length == 0) revert InvalidParams(); // prevent EOA registration
        // Require ERC-165 support for IBridgeAdapter
        if (
            !ERC165Checker.supportsInterface(
                adapter,
                type(IBridgeAdapter).interfaceId
            )
        ) {
            revert InvalidParams();
        }

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
        emit RouterPaused(msg.sender);
    }

    /// @inheritdoc IBridgeRouter
    function unpause() external onlyGovernor {
        paused = false;
        emit RouterUnpaused(msg.sender);
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

    /// @notice Retries a previously failed delivery with optional recipient override. Only callable by keeper.
    /// @param operationId The failed operation identifier
    /// @param newRecipient New recipient address; pass address(0) to use original recipient
    function retryFailedDelivery(
        bytes32 operationId,
        address newRecipient
    ) external nonReentrant onlyKeeper whenNotPaused {
        FailedDeliveryRecord memory r = failedDeliveries[operationId];

        if (r.failedAt == 0) revert InvalidParams();

        // State reads should not be retryable as they are read-only operations
        if (r.operationType == BridgeTypes.OperationType.READ_STATE) {
            revert UnsupportedOperationType();
        }

        // Use the original adapter - no override needed
        address effectiveAdapter = r.adapter;

        // Retrieve the payload from the failed delivery record
        bytes memory effectivePayload = r.operationPayload;

        // Apply recipient override if provided
        // validation happens inside _applyRecipientOverride
        effectivePayload = _applyRecipientOverride(
            r.operationType,
            effectivePayload,
            newRecipient
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
                        RETRY RECIPIENT OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Applies recipient override to the operation payload
     * @param operationType Type of operation being retried
     * @param originalPayload The original payload
     * @param newRecipient The new recipient address
     * @return modifiedPayload The payload with recipient override applied
     * @dev Applies recipient override and validates ark <> fleet (peer) relationship for the final recipient
     */
    function _applyRecipientOverride(
        BridgeTypes.OperationType operationType,
        bytes memory originalPayload,
        address newRecipient
    ) internal view returns (bytes memory modifiedPayload) {
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            // Apply recipient override (use original if newRecipient is zero)
            address finalRecipient = newRecipient != address(0)
                ? newRecipient
                : params.recipient;

            // Validate ark-fleet (peer) relationship for the final recipient
            _validatePeerRelationship(
                params.originator,
                finalRecipient,
                params.sourceChainId
            );

            // Update the payload with the final recipient
            params.recipient = finalRecipient;

            return abi.encode(params);
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedMessageParams)
            );

            // Apply recipient override (use original if newRecipient is zero)
            address finalRecipient = newRecipient != address(0)
                ? newRecipient
                : params.recipient;

            // Validate ark-fleet (peer) relationship for the final recipient
            _validatePeerRelationship(
                params.originator,
                finalRecipient,
                params.sourceChainId
            );

            // Update the payload with the final recipient
            params.recipient = finalRecipient;

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
     * @notice Validates that an ark <> fleet (peer) relationship is valid in both directions
     * @param originator The originator address (sender-side peer)
     * @param recipient The recipient address (receiver-side peer)
     * @param sourceChainId The source chain ID
     */
    function _validatePeerRelationship(
        address originator,
        address recipient,
        uint16 sourceChainId
    ) internal view {
        bool isValidPair = CROSS_CHAIN_REGISTRY.isValidCrossChainPair(
            originator,
            recipient,
            sourceChainId,
            uint16(block.chainid),
            CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
        );

        if (!isValidPair) {
            revert InvalidRecipient();
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
