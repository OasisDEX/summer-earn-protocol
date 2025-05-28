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

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters.
 *      Operations can only be initiated via the BridgeQueue or governance.
 */
contract BridgeRouter is IBridgeRouter, ProtocolAccessManaged, ReentrancyGuard {
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
        operationId = keccak256(
            abi.encode(
                block.chainid,
                destinationChainId,
                asset,
                amount,
                recipient,
                additionalData,
                block.timestamp,
                operationType
            )
        );

        // Set initial status to QUEUED
        operationStatuses[operationId] = BridgeTypes.OperationStatus.QUEUED;

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

        // Get required base fee and selected adapter (no multiplier)
        (uint256 requiredBaseFee, , address selectedAdapter) = _quote(
            params.destinationChainId,
            params.asset,
            params.amount,
            params.options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Validate fee provided by BridgeQueue
        _validateFee(msg.value, requiredBaseFee);

        // Use the base fee required by the adapter
        uint256 baseFeeToSend = requiredBaseFee;

        _validateAdapterSupportsOperation(
            selectedAdapter,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Pull tokens from BridgeQueue to Router first
        IERC20(params.asset).safeTransferFrom(
            bridgeQueue, // BridgeQueue approved us
            address(this), // Transfer to Router
            params.amount
        );

        // Now approve the adapter to spend Router's tokens
        IERC20(params.asset).approve(selectedAdapter, 0);
        IERC20(params.asset).approve(selectedAdapter, params.amount);

        // Notify originator that assets are now officially in-flight
        // Attempt to call updateInflightAssets if the originator supports it
        if (params.originator.code.length > 0) {
            try
                IERC165(params.originator).supportsInterface(
                    type(ICrossChainArk).interfaceId
                )
            returns (bool supported) {
                if (supported) {
                    try
                        ICrossChainArk(params.originator).updateInflightAssets(
                            params.amount
                        )
                    {} catch {
                        // Ignore failures in updateInflightAssets
                    }
                }
            } catch {
                // Originator doesn't support ERC165 or ICrossChainArk, ignore
            }
        }

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.recipient,
            abi.encode(params.originator) // Additional data for uniqueness
        );

        // Set up operation to adapter mapping BEFORE the adapter call
        operationToAdapter[operationId] = selectedAdapter;

        // Call adapter with the router-generated operation ID (no return value)
        ISendAdapter(selectedAdapter).transferAsset{value: baseFeeToSend}(
            operationId, // Pass the router-generated ID
            params.destinationChainId,
            params.asset,
            params.recipient,
            params.amount,
            params.originator,
            params.options.adapterParams
        );

        emit TransferInitiated(
            operationId,
            params.destinationChainId,
            params.asset,
            params.amount,
            params.recipient,
            selectedAdapter
        );

        // Refund excess fee after state changes
        _refund(params.originator, msg.value - requiredBaseFee);

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

        // Get required base fee and selected adapter (no multiplier)
        (uint256 requiredBaseFee, , address selectedAdapter) = _quote(
            params.dstChainId,
            address(0), // No asset
            0, // No amount
            params.options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Validate fee provided by BridgeQueue
        _validateFee(msg.value, requiredBaseFee);

        // Use the base fee required by the adapter
        uint256 baseFeeToSend = requiredBaseFee;

        _validateAdapterSupportsOperation(
            selectedAdapter,
            BridgeTypes.OperationType.READ_STATE
        );

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
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
            )
        );

        // Set operation to adapter mapping BEFORE the adapter call
        operationToAdapter[operationId] = selectedAdapter;

        // Store the originator for response delivery
        readRequestToOriginator[operationId] = params.originator;

        // Call adapter with the router-generated operation ID (no return value)
        ISendAdapter(selectedAdapter).readState{value: baseFeeToSend}(
            operationId, // Pass the router-generated ID
            uint16(block.chainid),
            params.dstChainId,
            params.dstContract,
            params.selector,
            params.readParams,
            params.originator,
            params.options.adapterParams
        );

        emit ReadRequestInitiated(
            operationId,
            params.dstChainId,
            params.dstContract,
            params.selector,
            params.readParams,
            selectedAdapter
        );

        // Refund excess fee after state changes
        _refund(params.originator, msg.value - requiredBaseFee);

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

        // Get required base fee and selected adapter (no multiplier)
        (uint256 requiredBaseFee, , address selectedAdapter) = _quote(
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            params.options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Validate fee provided by BridgeQueue
        _validateFee(msg.value, requiredBaseFee);

        // Use the base fee required by the adapter
        uint256 baseFeeToSend = requiredBaseFee;

        _validateAdapterSupportsOperation(
            selectedAdapter,
            BridgeTypes.OperationType.MESSAGE
        );

        // Generate the operation ID ONCE - Router is the source of truth
        operationId = _generateOperationId(
            BridgeTypes.OperationType.MESSAGE,
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            params.recipient,
            abi.encode(params.message, params.originator)
        );

        operationToAdapter[operationId] = selectedAdapter;

        // Call adapter with the router-generated operation ID (no return value)
        ISendAdapter(selectedAdapter).sendMessage{value: baseFeeToSend}(
            operationId, // Pass the router-generated ID
            params.destinationChainId,
            params.recipient,
            params.message,
            params.originator, // Pass originator to adapter
            params.options.adapterParams
        );

        emit MessageInitiated(
            operationId,
            params.destinationChainId,
            params.recipient,
            selectedAdapter
        );

        // Refund excess fee after state changes
        _refund(params.originator, msg.value - requiredBaseFee);

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal implementation of quote that handles adapter selection and gets the base fee.
     * @param destinationChainId ID of the destination chain.
     * @param asset Address of the asset to transfer.
     * @param amount Amount of the asset to transfer.
     * @param options Additional options for the transfer.
     * @param operationType Type of operation being performed.
     * @return nativeFee Base fee in native token required by the adapter.
     * @return tokenFee Base fee in the asset token required by the adapter.
     * @return selectedAdapter Address of the selected adapter.
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
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        selectedAdapter = options.specifiedAdapter;

        // If no adapter specified, revert
        if (selectedAdapter == address(0)) {
            revert NoSuitableAdapter();
        } else {
            // Validate specified adapter
            if (!this.isValidAdapter(selectedAdapter)) {
                revert UnknownAdapter();
            }
        }

        _validateAdapterSupportsOperation(selectedAdapter, operationType);

        // Get base fee from the selected adapter
        (nativeFee, tokenFee) = IBridgeAdapter(selectedAdapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options.adapterParams,
            operationType
        );

        return (nativeFee, tokenFee, selectedAdapter);
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
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        return
            _quote(destinationChainId, asset, amount, options, operationType);
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
}
