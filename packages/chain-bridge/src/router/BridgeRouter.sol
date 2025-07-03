// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ICrossChainStateReadReceiver} from "../interfaces/ICrossChainStateReadReceiver.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ICrossChainArk} from "../interfaces/ICrossChainArk.sol";
import {IInflightAssetTracking} from "../interfaces/IInflightAssetTracking.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters.
 *      Operations can only be initiated via the BridgeQueue or governance.
 */
contract BridgeRouter is
    IBridgeRouter,
    ProtocolAccessManaged,
    ReentrancyGuard,
    Nonces
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Set of registered adapters
    EnumerableSet.AddressSet private adapters;

    /// @notice Mapping of operation IDs to their current status
    mapping(bytes32 operationId => BridgeTypes.OperationStatus status)
        public operationStatuses;

    /// @notice Mapping of operation IDs to the adapter that processed them
    mapping(bytes32 operationId => address adapterAddress)
        public operationToAdapter;

    /// @notice Mapping of request IDs to the adapter that processed them
    mapping(bytes32 requestId => address receivingAdapter)
        public requestReceivedByAdapter;

    /// @notice Mapping to track read request originators
    mapping(bytes32 requestId => address originator)
        public readRequestToOriginator;

    /// @notice Pause state of the router
    bool public paused;

    /// @notice Mapping of chain IDs to their BridgeRouter addresses
    mapping(uint16 chainId => address routerAddress)
        public chainToRouterAddress;

    /// @notice Address of the associated BridgeQueue
    address public bridgeQueue;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BridgeRouter contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @param _bridgeQueue Address of the BridgeQueue contract
     */
    constructor(
        address accessManager,
        address _bridgeQueue
    ) ProtocolAccessManaged(accessManager) {
        bridgeQueue = _bridgeQueue;
        emit BridgeQueueUpdated(_bridgeQueue);
    }

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
     * @dev Modifier ensuring the caller (`msg.sender`) is the configured `bridgeQueue`.
     * Reverts with `OnlyBridgeQueue` if the caller is not the `bridgeQueue` address.
     */
    modifier onlyBridgeQueue() {
        if (msg.sender != bridgeQueue) revert OnlyBridgeQueue();
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
            params.recipient == address(0) ||
            params.originator == address(0) ||
            params.asset == address(0)
        ) revert InvalidParams();
    }

    /**
     * @dev Internal function to validate fleet deposit parameters
     * @param params Parameters to validate
     */
    function _validateFleetDepositParams(
        BridgeTypes.ExecuteUserFleetDepositParams calldata params
    ) internal pure {
        if (
            params.amount == 0 ||
            params.asset == address(0) ||
            params.fleetCommander == address(0) ||
            params.shareRecipient == address(0)
        ) revert InvalidParams();
    }

    /**
     * @dev Internal function to validate read state parameters
     * @param params Parameters to validate
     */
    function _validateReadStateParams(
        BridgeTypes.ExecuteReadStateParams calldata params
    ) internal pure {
        if (params.originator == address(0) || params.dstContract == address(0))
            revert InvalidParams();
    }

    /**
     * @dev Internal function to validate send message parameters
     * @param params Parameters to validate
     */
    function _validateSendMessageParams(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) internal pure {
        if (params.recipient == address(0) || params.originator == address(0))
            revert InvalidParams();
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
     * @dev Internal function to validate provided fee against required fee
     * @param providedFee The fee provided with the transaction
     * @param requiredFee The required fee for the operation
     */
    function _validateFee(
        uint256 providedFee,
        uint256 requiredFee
    ) internal pure {
        if (providedFee < requiredFee) revert InsufficientFee();
    }

    /**
     * @dev Internal function to handle refunds safely
     * @param recipient Address to receive the refund
     * @param amount Amount to refund
     */
    function _refund(address recipient, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }

    /**
     * @dev Internal function to generate a unique operation ID and set initial status
     * @param operationType Type of operation being performed
     * @param destinationChainId Target chain ID
     * @param asset Asset address (address(0) for non-asset operations)
     * @param amount Amount (0 for non-asset operations)
     * @param recipient Recipient address
     * @param additionalData Additional data for ID generation (contract address, selector, etc.)
     * @return operationId The generated operation ID
     */
    function _generateOperationId(
        BridgeTypes.OperationType operationType,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
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
                recipient,
                additionalData,
                currentNonce,
                operationType
            )
        );

        // Set initial status to QUEUED
        operationStatuses[operationId] = BridgeTypes.OperationStatus.QUEUED;

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
     * @dev Validates operation parameters and returns adapter and buffered fee
     * @param destinationChainId Target chain ID
     * @param asset Asset address
     * @param amount Amount to transfer
     * @param options Bridge options including adapter specification
     * @param operationType Type of operation being performed
     * @return specifiedAdapter The validated adapter address
     * @return bufferedFee The fee with buffer applied
     */
    function _validateAndGetAdapter(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions memory options,
        BridgeTypes.OperationType operationType
    ) internal view returns (address specifiedAdapter, uint256 bufferedFee) {
        // Get required base fee and specified adapter
        (uint256 requiredBaseFee, , address adapter) = _quote(
            destinationChainId,
            asset,
            amount,
            options,
            operationType
        );

        // Apply fee buffer to account for fee volatility
        bufferedFee = _applyFeeBuffer(requiredBaseFee);

        // Validate fee provided against buffered fee
        _validateFee(msg.value, bufferedFee);

        _validateAdapterSupportsOperation(adapter, operationType);

        return (adapter, bufferedFee);
    }

    /**
     * @dev Transfers tokens from source to router and approves adapter
     * @param asset Token address
     * @param amount Amount to transfer
     * @param from Source address (where tokens come from)
     * @param adapter Adapter address to approve
     */
    function _transferTokensToAdapter(
        address asset,
        uint256 amount,
        address from,
        address adapter
    ) internal {
        // Pull tokens from source to Router
        IERC20(asset).safeTransferFrom(from, address(this), amount);

        // Approve the adapter to spend Router's tokens
        IERC20(asset).forceApprove(adapter, amount);
    }

    /**
     * @dev Notifies originator about inflight assets if supported
     * @param originator Address to notify
     * @param amount Amount that's now inflight
     */
    function _notifyInflightAssets(
        address originator,
        uint256 amount
    ) internal {
        // Notify originator that assets are now officially in-flight
        if (originator.code.length > 0) {
            try
                IERC165(originator).supportsInterface(
                    type(IInflightAssetTracking).interfaceId
                )
            returns (bool supported) {
                if (supported) {
                    try
                        IInflightAssetTracking(originator).updateInflightAssets(
                            amount
                        )
                    {} catch {
                        // Ignore failures in updateInflightAssets
                    }
                }
            } catch {
                // Originator doesn't support ERC165 or IInflightAssetTracking, ignore
            }
        }
    }

    /**
     * @dev Generates operation ID and sets up adapter mapping
     * @param operationType Type of operation
     * @param destinationChainId Target chain
     * @param asset Asset address
     * @param amount Amount
     * @param recipient Recipient address
     * @param additionalData Additional data for ID generation
     * @param adapter Adapter address to map to operation
     * @return operationId Generated operation ID
     */
    function _generateAndSetupOperation(
        BridgeTypes.OperationType operationType,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        bytes memory additionalData,
        address adapter
    ) internal returns (bytes32 operationId) {
        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            operationType,
            destinationChainId,
            asset,
            amount,
            recipient,
            additionalData
        );

        // Set up operation to adapter mapping BEFORE the adapter call
        operationToAdapter[operationId] = adapter;

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                           BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params
    )
        external
        payable
        onlyBridgeQueue
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateTransferParams(params);

        // Validate and get adapter with buffered fee
        (
            address specifiedAdapter,
            uint256 bufferedFee
        ) = _validateAndGetAdapter(
                params.destinationChainId,
                params.asset,
                params.amount,
                params.options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            );

        // Transfer tokens from BridgeQueue to adapter via router
        _transferTokensToAdapter(
            params.asset,
            params.amount,
            bridgeQueue,
            specifiedAdapter
        );

        // Notify originator about inflight assets
        _notifyInflightAssets(params.originator, params.amount);

        // Generate operation ID and setup mapping
        operationId = _generateAndSetupOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.recipient,
            abi.encode(params.originator),
            specifiedAdapter
        );

        // Call adapter with the buffered fee
        ISendAdapter(specifiedAdapter).transferAsset{value: bufferedFee}(
            operationId,
            params.destinationChainId,
            params.asset,
            params.recipient,
            params.amount,
            params.message,
            params.originator,
            params.refundAddress,
            params.options.adapterParams
        );

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.recipient,
            specifiedAdapter
        );

        return operationId;
    }

    /**
     * @notice Executes a user-initiated fleet deposit operation
     * @dev Public method that allows users to initiate fleet deposits directly through FleetDepositManager
     * @param params Fleet deposit parameters including destination, asset, amounts, and options
     * @return operationId Unique identifier for the cross-chain operation
     */
    function executeUserFleetDeposit(
        BridgeTypes.ExecuteUserFleetDepositParams calldata params
    )
        external
        payable
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateFleetDepositParams(params);

        // Validate adapter supports fleet deposits specifically
        address specifiedAdapter = params.options.specifiedAdapter;
        if (specifiedAdapter == address(0)) revert NoSuitableAdapter();
        if (!this.isValidAdapter(specifiedAdapter)) revert UnknownAdapter();

        _validateAdapterSupportsOperation(
            specifiedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Get fee quote for fleet deposit operation
        (uint256 requiredBaseFee, ) = IBridgeAdapter(specifiedAdapter)
            .estimateFee(
                params.destinationChainId,
                params.asset,
                params.amount,
                params.options.adapterParams,
                BridgeTypes.OperationType.TRANSFER_ASSET
            );

        // Apply fee buffer and validate
        uint256 bufferedFee = _applyFeeBuffer(requiredBaseFee);
        _validateFee(msg.value, bufferedFee);

        // Transfer tokens from caller to adapter via router
        _transferTokensToAdapter(
            params.asset,
            params.amount,
            msg.sender,
            specifiedAdapter
        );

        // Generate operation ID for fleet deposit
        operationId = _generateAndSetupOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.shareRecipient,
            abi.encode(
                params.fleetCommander,
                params.shareRecipient,
                params.originalUser
            ),
            specifiedAdapter
        );

        // Call adapter's transferAsset method instead of fleet deposit specific method
        ISendAdapter(specifiedAdapter).transferAsset{value: bufferedFee}(
            operationId,
            params.destinationChainId,
            params.asset,
            params.shareRecipient,
            params.amount,
            params.message,
            params.originalUser,
            params.originalUser, // Refund address is the original user
            params.options.adapterParams
        );

        // Emit fleet deposit specific event
        emit FleetDepositInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.fleetCommander,
            params.shareRecipient,
            specifiedAdapter
        );

        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params
    )
        external
        payable
        onlyBridgeQueue
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateReadStateParams(params);

        // Validate and get adapter with buffered fee
        (
            address specifiedAdapter,
            uint256 bufferedFee
        ) = _validateAndGetAdapter(
                params.dstChainId,
                address(0), // No asset
                0, // No amount
                params.options,
                BridgeTypes.OperationType.READ_STATE
            );

        // Generate operation ID and setup mapping
        operationId = _generateAndSetupOperation(
            BridgeTypes.OperationType.READ_STATE,
            params.dstChainId,
            address(0), // No asset
            0, // No amount
            address(0), // No recipient for read operations
            abi.encode(
                params.dstContract,
                params.selector,
                params.readParams,
                params.originator
            ),
            specifiedAdapter
        );

        // Store the originator for response delivery
        readRequestToOriginator[operationId] = params.originator;

        // Call adapter with the buffered fee
        ISendAdapter(specifiedAdapter).readState{value: bufferedFee}(
            operationId,
            uint16(block.chainid),
            params.dstChainId,
            params.dstContract,
            params.selector,
            params.readParams,
            params.refundAddress,
            params.options.adapterParams
        );

        emit ReadRequestInitiated(
            operationId,
            params.dstChainId,
            params.dstContract,
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
        BridgeTypes.ExecuteSendMessageParams calldata params
    )
        external
        payable
        onlyBridgeQueue
        whenNotPaused
        nonReentrant
        returns (bytes32 operationId)
    {
        _validateSendMessageParams(params);

        // Validate and get adapter with buffered fee
        (
            address specifiedAdapter,
            uint256 bufferedFee
        ) = _validateAndGetAdapter(
                params.destinationChainId,
                address(0), // No asset
                0, // No amount
                params.options,
                BridgeTypes.OperationType.MESSAGE
            );

        // Generate operation ID and setup mapping
        operationId = _generateAndSetupOperation(
            BridgeTypes.OperationType.MESSAGE,
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            params.recipient,
            abi.encode(params.message, params.originator),
            specifiedAdapter
        );

        // Call adapter with the buffered fee
        ISendAdapter(specifiedAdapter).sendMessage{value: bufferedFee}(
            operationId,
            params.destinationChainId,
            params.recipient,
            params.message,
            params.refundAddress,
            params.options.adapterParams
        );

        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.recipient,
            specifiedAdapter
        );

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal implementation of quote that validates the specified adapter and gets the base fee.
     * @param destinationChainId ID of the destination chain.
     * @param asset Address of the asset to transfer.
     * @param amount Amount of the asset to transfer.
     * @param options Additional options for the transfer.
     * @param operationType Type of operation being performed.
     * @return nativeFee Base fee in native token required by the adapter.
     * @return tokenFee Base fee in the asset token required by the adapter.
     * @return specifiedAdapter Address of the specified adapter.
     */
    function _quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions memory options,
        BridgeTypes.OperationType operationType
    )
        internal
        view
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter)
    {
        specifiedAdapter = options.specifiedAdapter;

        // If no adapter specified, revert
        if (specifiedAdapter == address(0)) {
            revert NoSuitableAdapter();
        } else {
            // Validate specified adapter
            if (!this.isValidAdapter(specifiedAdapter)) {
                revert UnknownAdapter();
            }
        }

        _validateAdapterSupportsOperation(specifiedAdapter, operationType);

        // Get base fee from the specified adapter
        (nativeFee, tokenFee) = IBridgeAdapter(specifiedAdapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options.adapterParams,
            operationType
        );

        return (nativeFee, tokenFee, specifiedAdapter);
    }

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
        // Get the base fee from internal quote
        (uint256 baseFee, uint256 baseTokenFee, address adapter) = _quote(
            destinationChainId,
            asset,
            amount,
            options,
            operationType
        );

        // Apply fee buffer to account for fee volatility
        uint256 bufferedNativeFee = _applyFeeBuffer(baseFee);

        return (bufferedNativeFee, baseTokenFee, adapter);
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external onlyRegisteredAdapter {
        if (operationToAdapter[operationId] != msg.sender)
            revert Unauthorized();

        // Allow transitions from QUEUED to SENT, or from SENT to FAILED
        if (
            status == BridgeTypes.OperationStatus.SENT &&
            operationStatuses[operationId] == BridgeTypes.OperationStatus.QUEUED
        ) {
            operationStatuses[operationId] = status;
            emit OperationStatusUpdated(operationId, status);
        } else if (
            status == BridgeTypes.OperationStatus.FAILED &&
            operationStatuses[operationId] == BridgeTypes.OperationStatus.SENT
        ) {
            operationStatuses[operationId] = status;
            emit OperationStatusUpdated(operationId, status);
        }
    }

    /// @inheritdoc IBridgeRouter
    function updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    ) external onlyRegisteredAdapter {
        requestReceivedByAdapter[requestId] = msg.sender;

        // Only update status if it's a failure
        if (status == BridgeTypes.OperationStatus.FAILED) {
            operationStatuses[requestId] = status;
            emit OperationStatusUpdated(requestId, status);
        }

        // Always emit delivery event
        emit MessageDelivered(
            requestId,
            recipient,
            status != BridgeTypes.OperationStatus.FAILED
        );
    }

    /// @inheritdoc IBridgeRouter
    function notifyMessageReceived(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) external onlyRegisteredAdapter {
        // Store which adapter received this request
        requestReceivedByAdapter[operationId] = msg.sender;

        // Emit events for tracking
        emit MessageDelivered(operationId, recipient, true);

        // If this is a transfer, emit the transfer event
        if (asset != address(0) && amount > 0) {
            emit TransferReceived(
                operationId,
                asset,
                amount,
                recipient,
                sourceChainId
            );
        }
    }

    /// @inheritdoc IBridgeRouter
    function deliverReadResponse(
        bytes32 operationId,
        uint16 sourceChainId,
        bytes calldata resultData
    ) external nonReentrant onlyRegisteredAdapter {
        if (operationToAdapter[operationId] != msg.sender) {
            revert Unauthorized();
        }

        address originator = readRequestToOriginator[operationId];
        if (originator == address(0)) revert InvalidParams();

        // Try to deliver the response
        bool delivered = false;

        // Check if the originator implements the ICrossChainStateReadReceiver interface
        bytes4 interfaceId = type(ICrossChainStateReadReceiver).interfaceId;
        try
            ICrossChainStateReadReceiver(originator).supportsInterface(
                interfaceId
            )
        returns (bool supported) {
            if (supported) {
                try
                    ICrossChainStateReadReceiver(originator).receiveStateRead(
                        resultData,
                        originator,
                        operationId,
                        sourceChainId
                    )
                {
                    delivered = true;
                } catch {
                    delivered = false;
                }
            } else {
                (bool success, ) = originator.call(
                    abi.encodeWithSelector(
                        ICrossChainStateReadReceiver.receiveStateRead.selector,
                        resultData,
                        originator,
                        operationId,
                        sourceChainId
                    )
                );
                delivered = success;
            }
        } catch {
            delivered = false;
        }

        // Emit event based on delivery result
        emit ReadResponseDelivered(operationId, originator, delivered);

        // Only update status if delivery failed
        if (!delivered) {
            operationStatuses[operationId] = BridgeTypes.OperationStatus.FAILED;
            emit OperationStatusUpdated(
                operationId,
                BridgeTypes.OperationStatus.FAILED
            );
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

    /// @inheritdoc IBridgeRouter
    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
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
    function recoverFunds(
        address recipient,
        uint256 amount
    ) external onlyGovernor nonReentrant {
        if (recipient == address(0)) revert InvalidParams();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit RouterFundsRecovered(recipient, amount);
    }

    /// @inheritdoc IBridgeRouter
    function setChainRouterAddress(
        uint16 chainId,
        address routerAddress
    ) external onlyGovernor {
        chainToRouterAddress[chainId] = routerAddress;
        emit ChainRouterAddressUpdated(chainId, routerAddress);
    }

    /// @inheritdoc IBridgeRouter
    function recoverOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus newStatus
    ) external onlyGovernor {
        // Update the operation status
        operationStatuses[operationId] = newStatus;

        // Emit the status update event
        emit OperationStatusUpdated(operationId, newStatus);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return (interfaceId == type(IBridgeRouter).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }

    /// @notice Sets the BridgeQueue address. Can only be called by governance.
    /// @param _newBridgeQueue The new BridgeQueue address
    function setBridgeQueue(address _newBridgeQueue) external onlyGovernor {
        if (_newBridgeQueue == address(0)) revert InvalidBridgeQueue();
        bridgeQueue = _newBridgeQueue;
        emit BridgeQueueUpdated(_newBridgeQueue);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a fleet deposit operation is initiated
    event FleetDepositInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed asset,
        uint256 amount,
        address fleetCommander,
        address shareRecipient,
        address adapter
    );
}
