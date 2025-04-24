// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters
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

    /// @notice Add a new mapping to track confirmation statuses
    mapping(bytes32 operationId => bool confirmed) public confirmationSent;

    /// @notice Fee multiplier for confirmations (200 = double the fee, with half for confirmation)
    uint256 public feeMultiplier = 200; // 200%

    /// @notice Standard gas limit for confirmation transactions
    uint64 public confirmationGasLimit = 200000; // Default reasonable gas limit for confirmations

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
     * @param chainIds Array of chain IDs to configure
     * @param routerAddresses Array of corresponding router addresses
     */
    constructor(
        address accessManager,
        address _bridgeQueue,
        uint16[] memory chainIds,
        address[] memory routerAddresses
    ) ProtocolAccessManaged(accessManager) {
        if (
            chainIds.length != routerAddresses.length ||
            _bridgeQueue == address(0)
        ) revert InvalidParams();

        bridgeQueue = _bridgeQueue;

        // Set up initial chain-to-router mappings
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (routerAddresses[i] != address(0)) {
                chainToRouterAddress[chainIds[i]] = routerAddresses[i];
                emit ChainRouterAddressUpdated(chainIds[i], routerAddresses[i]);
            }
        }
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

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal implementation of quote that handles adapter selection and fee calculation.
     * @param destinationChainId ID of the destination chain.
     * @param asset Address of the asset to transfer.
     * @param amount Amount of the asset to transfer.
     * @param options Additional options for the transfer.
     * @param operationType Type of operation being performed.
     * @param applyMultiplier Whether to apply the router's fee multiplier.
     * @return nativeFee Fee in native token (base or total depending on applyMultiplier).
     * @return tokenFee Fee in the asset token (base or total depending on applyMultiplier).
     * @return selectedAdapter Address of the selected adapter.
     */
    function _quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions memory options,
        BridgeTypes.OperationType operationType,
        bool applyMultiplier
    )
        internal
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        // Select adapter - either user specified or find best
        selectedAdapter = options.specifiedAdapter;

        if (selectedAdapter != address(0)) {
            if (!adapters.contains(selectedAdapter)) revert UnknownAdapter();
            // Adapter capability checks remain the same...
            if (
                operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
                !IBridgeAdapter(selectedAdapter).supportsAssetTransfer()
            ) {
                revert UnsupportedAdapterOperation();
            }

            if (
                operationType == BridgeTypes.OperationType.READ_STATE &&
                !IBridgeAdapter(selectedAdapter).supportsStateRead()
            ) {
                revert UnsupportedAdapterOperation();
            }

            if (
                operationType == BridgeTypes.OperationType.MESSAGE &&
                !IBridgeAdapter(selectedAdapter).supportsMessaging()
            ) {
                revert UnsupportedAdapterOperation();
            }
        } else {
            // Finding the best adapter doesn't need the multiplier applied yet
            selectedAdapter = _getBestAdapterForOperation(
                destinationChainId,
                asset,
                amount,
                operationType
            );
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Get base fee from the selected adapter
        (uint256 baseNativeFee, uint256 baseTokenFee) = IBridgeAdapter(
            selectedAdapter
        ).estimateFee(
                destinationChainId,
                asset,
                amount,
                options.adapterParams,
                operationType
            );

        // Apply multiplier only if requested
        if (applyMultiplier) {
            nativeFee = (baseNativeFee * feeMultiplier) / 100;
            tokenFee = (baseTokenFee * feeMultiplier) / 100;
            // Handle potential rounding down to zero if base fee is small but non-zero
            if (nativeFee == 0 && baseNativeFee > 0) nativeFee = 1;
            if (tokenFee == 0 && baseTokenFee > 0) tokenFee = 1;
        } else {
            nativeFee = baseNativeFee;
            tokenFee = baseTokenFee;
        }

        // selectedAdapter is now determined and returned alongside fees
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
        // External quote always applies the multiplier for user visibility
        return
            _quote(
                destinationChainId,
                asset,
                amount,
                options,
                operationType,
                true // Apply multiplier for external quote
            );
    }

    /// @inheritdoc IBridgeRouter
    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId) {
        // Perform token transfer first
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Call the INTERNAL execute function with isBridgeQueueCall = false
        operationId = _executeTransferAssets(
            destinationChainId,
            asset,
            amount,
            recipient,
            msg.sender, // originator is msg.sender for direct calls
            options,
            false // Indicate it's NOT a BridgeQueue call
        );

        return operationId;
    }

    /// @inheritdoc IBridgeRouter
    function readState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId) {
        // Call execute with isBridgeQueueCall = false, forwarding msg.value
        operationId = _executeReadState(
            dstChainId,
            dstContract,
            selector,
            readParams,
            msg.sender, // originator is msg.sender
            options,
            false // Indicate it's NOT a BridgeQueue call
        );
        return operationId;
    }

    /// @inheritdoc IBridgeRouter
    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId) {
        // Call execute with isBridgeQueueCall = false, forwarding msg.value
        operationId = _executeSendMessage(
            destinationChainId,
            recipient,
            message,
            msg.sender, // originator is msg.sender
            options,
            false // Indicate it's NOT a BridgeQueue call
        );
        return operationId;
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

        if (!_isStatusProgression(operationStatuses[operationId], status))
            revert InvalidStatus();

        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
    }

    /// @inheritdoc IBridgeRouter
    function updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    ) external onlyRegisteredAdapter {
        requestReceivedByAdapter[requestId] = msg.sender;

        // Update the status
        if (!_isStatusProgression(operationStatuses[requestId], status))
            revert InvalidStatus();

        operationStatuses[requestId] = status;
        emit OperationStatusUpdated(requestId, status);

        if (status != BridgeTypes.OperationStatus.DELIVERED) {
            emit MessageDelivered(requestId, recipient, false);
        }
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

        // Set initial status to DELIVERED
        operationStatuses[operationId] = BridgeTypes.OperationStatus.DELIVERED;
        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );

        emit MessageDelivered(operationId, recipient, true);

        // If this is a transfer (asset is not zero and amount > 0), emit the transfer event
        if (asset != address(0) && amount > 0) {
            emit TransferReceived(
                operationId,
                asset,
                amount,
                recipient,
                sourceChainId
            );
        }

        // Try to send confirmation back to source chain
        if (!confirmationSent[operationId]) {
            try
                ISendAdapter(msg.sender).sendMessage(
                    sourceChainId,
                    chainToRouterAddress[sourceChainId] != address(0)
                        ? chainToRouterAddress[sourceChainId]
                        : address(this), // Fallback to this address if not configured
                    abi.encode(
                        operationId,
                        BridgeTypes.OperationStatus.COMPLETED
                    ),
                    address(0), // No refund address needed
                    BridgeTypes.AdapterParams({
                        gasLimit: confirmationGasLimit,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                )
            returns (bytes32) {
                confirmationSent[operationId] = true;
            } catch {
                emit ConfirmationFailed(operationId);
            }
        }
    }

    /// @inheritdoc IBridgeRouter
    function deliverReadResponse(
        bytes32 operationId,
        bytes calldata resultData
    ) external onlyRegisteredAdapter {
        if (operationToAdapter[operationId] != msg.sender)
            revert Unauthorized();

        address originator = readRequestToOriginator[operationId];
        if (originator == address(0)) revert InvalidParams();

        // Try to deliver the response
        bool delivered = false;

        // Check if the originator implements the ICrossChainReceiver interface
        bytes4 interfaceId = type(ICrossChainReceiver).interfaceId;
        try
            ICrossChainReceiver(originator).supportsInterface(interfaceId)
        returns (bool supported) {
            if (supported) {
                // Call the receiver's receiveStateRead method
                try
                    ICrossChainReceiver(originator).receiveStateRead(
                        resultData,
                        originator,
                        0, // sourceChainId (could be added as a parameter if needed)
                        operationId
                    )
                {
                    delivered = true;
                } catch {
                    // Delivery failed, but don't revert
                    delivered = false;
                }
            } else {
                // Fallback for contracts that don't implement supportsInterface
                // Just attempt to call the method directly
                (bool success, ) = originator.call(
                    abi.encodeWithSelector(
                        ICrossChainReceiver.receiveStateRead.selector,
                        resultData,
                        originator,
                        0, // sourceChainId
                        operationId
                    )
                );
                delivered = success;
            }
        } catch {
            // Fallback for contracts that don't implement supportsInterface
            // Just attempt to call the method directly
            (bool success, ) = originator.call(
                abi.encodeWithSelector(
                    ICrossChainReceiver.receiveStateRead.selector,
                    resultData,
                    originator,
                    0, // sourceChainId
                    operationId
                )
            );
            delivered = success;
        }

        // Update status based on delivery result
        if (delivered) {
            operationStatuses[operationId] = BridgeTypes
                .OperationStatus
                .COMPLETED;
            emit OperationStatusUpdated(
                operationId,
                BridgeTypes.OperationStatus.COMPLETED
            );
            emit ReadResponseDelivered(operationId, originator, true);
        } else {
            operationStatuses[operationId] = BridgeTypes.OperationStatus.FAILED;
            emit OperationStatusUpdated(
                operationId,
                BridgeTypes.OperationStatus.FAILED
            );
            emit ReadResponseDelivered(operationId, originator, false);
        }
    }

    /// @inheritdoc IBridgeRouter
    function receiveConfirmation(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external onlyRegisteredAdapter {
        // Only update status in forward progression (pending->complete, not complete->pending)
        if (_isStatusProgression(operationStatuses[operationId], status)) {
            operationStatuses[operationId] = status;
            emit OperationStatusUpdated(operationId, status);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a status change represents forward progression.
     * @param currentStatus The current status of the operation.
     * @param newStatus The proposed new status.
     * @return True if the status change is valid forward progression.
     * @dev Defines valid transitions: PENDING -> DELIVERED/COMPLETED/FAILED, DELIVERED -> COMPLETED/FAILED.
     *      FAILED and COMPLETED are terminal states.
     */
    function _isStatusProgression(
        BridgeTypes.OperationStatus currentStatus,
        BridgeTypes.OperationStatus newStatus
    ) internal pure returns (bool) {
        // If current status is unset (default value), allow setting to PENDING
        if (currentStatus == BridgeTypes.OperationStatus(0)) {
            return true;
        }

        // Failed is a terminal state, can't progress from it
        if (currentStatus == BridgeTypes.OperationStatus.FAILED) {
            return false;
        }

        // Completed is a terminal state, can't progress from it
        if (currentStatus == BridgeTypes.OperationStatus.COMPLETED) {
            return false;
        }

        // Can always progress to FAILED from any non-terminal state
        if (newStatus == BridgeTypes.OperationStatus.FAILED) {
            return true;
        }

        // Status progression order: PENDING -> DELIVERED -> COMPLETED
        if (currentStatus == BridgeTypes.OperationStatus.PENDING) {
            return
                newStatus == BridgeTypes.OperationStatus.DELIVERED ||
                newStatus == BridgeTypes.OperationStatus.COMPLETED;
        }

        if (currentStatus == BridgeTypes.OperationStatus.DELIVERED) {
            return newStatus == BridgeTypes.OperationStatus.COMPLETED;
        }

        // Default: no progression
        return false;
    }

    /**
     * @notice Finds the best adapter for an operation based on compatibility and estimated fee.
     * @param chainId Destination or source chain ID.
     * @param asset Asset to send (address(0) for non-asset operations).
     * @param amount Amount to transfer (0 for non-asset operations).
     * @param operationType Type of operation to perform.
     * @return The address of the lowest-cost suitable adapter.
     * @dev Considers chain support, operation support, asset support (if applicable), and estimated fees.
     *      Applies the router's `feeMultiplier` to the adapter's base fee for comparison.
     */
    function _getBestAdapterForOperation(
        uint16 chainId,
        address asset,
        uint256 amount,
        BridgeTypes.OperationType operationType
    ) internal view returns (address) {
        address bestAdapter = address(0);
        uint256 lowestFee = type(uint256).max;

        uint256 adapterCount = adapters.length();
        for (uint256 i = 0; i < adapterCount; i++) {
            address adapter = adapters.at(i);

            // Check if adapter supports this chain
            if (!IBridgeAdapter(adapter).supportsChain(chainId)) continue;

            // Check capability support
            if (
                operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
                !IBridgeAdapter(adapter).supportsAssetTransfer()
            ) continue;
            if (
                operationType == BridgeTypes.OperationType.READ_STATE &&
                !IBridgeAdapter(adapter).supportsStateRead()
            ) continue;
            if (
                operationType == BridgeTypes.OperationType.MESSAGE &&
                !IBridgeAdapter(adapter).supportsMessaging()
            ) continue;

            // For asset transfers, check if the asset is supported
            if (
                asset != address(0) &&
                operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
                !IBridgeAdapter(adapter).supportsAsset(chainId, asset)
            ) continue;

            // If we get here, the adapter is suitable, so check its fee
            uint256 estimatedFee = 0;

            try
                IBridgeAdapter(adapter).estimateFee(
                    chainId,
                    asset,
                    amount,
                    BridgeTypes.AdapterParams({
                        gasLimit: 200000, // Use a reasonable default for estimation
                        calldataSize: 100, // Use a reasonable default for estimation
                        msgValue: 0,
                        options: ""
                    }),
                    operationType // Pass the operation type directly
                )
            returns (uint256 fee, uint256) {
                estimatedFee = fee;
            } catch {
                // If estimation fails, consider this adapter infinitely expensive
                estimatedFee = type(uint256).max;
            }

            // Apply router's fee multiplier to get total cost for comparison
            uint256 totalFee = type(uint256).max;
            if (estimatedFee != type(uint256).max) {
                if (feeMultiplier == 0) {
                    // Handle case where multiplier is 0, treat fee as max to avoid division by zero and prefer other adapters
                    totalFee = type(uint256).max;
                } else {
                    totalFee = (estimatedFee * feeMultiplier) / 100;
                    // Handle potential rounding down to zero
                    if (totalFee == 0 && estimatedFee > 0) totalFee = 1;
                }
            }

            // Update best adapter if this one is cheaper
            if (totalFee < lowestFee) {
                lowestFee = totalFee;
                bestAdapter = adapter;
            }
        }

        return bestAdapter;
    }

    /// @inheritdoc IBridgeRouter
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount,
        BridgeTypes.OperationType operationType
    ) public view returns (address) {
        return
            _getBestAdapterForOperation(chainId, asset, amount, operationType);
    }

    /// @inheritdoc IBridgeRouter
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount
    ) public view returns (address) {
        // Default to MESSAGE operation
        return
            getBestAdapter(
                chainId,
                asset,
                amount,
                BridgeTypes.OperationType.MESSAGE
            );
    }

    /// @inheritdoc IBridgeRouter
    function getBestAdapterForStateRead(
        uint16 chainId
    ) public view returns (address) {
        return
            getBestAdapter(
                chainId,
                address(0),
                0,
                BridgeTypes.OperationType.READ_STATE
            );
    }

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

    /// @inheritdoc IBridgeRouter
    function getRouterBalance() external view returns (uint256) {
        return address(this).balance;
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
    function setFeeMultiplier(uint256 multiplier) external onlyGovernor {
        if (multiplier < 100) revert InvalidParams(); // must at least cover base fee
        feeMultiplier = multiplier;
    }

    /// @inheritdoc IBridgeRouter
    function removeRouterFunds(
        address recipient,
        uint256 amount
    ) external onlyGovernor nonReentrant {
        if (recipient == address(0)) revert InvalidParams();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit RouterFundsRemoved(recipient, amount);
    }

    /// @inheritdoc IBridgeRouter
    function addRouterFunds() external payable {
        emit RouterFundsAdded(msg.sender, msg.value);
    }

    /// @inheritdoc IBridgeRouter
    function setConfirmationGasLimit(
        uint64 newConfirmationGasLimit
    ) external onlyGovernor {
        confirmationGasLimit = newConfirmationGasLimit;
        emit ConfirmationGasLimitUpdated(newConfirmationGasLimit);
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
    ) external view returns (bool) {
        return (interfaceId == type(IBridgeRouter).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                           BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyBridgeQueue returns (bytes32 operationId) {
        // Call the INTERNAL execute function with isBridgeQueueCall = true
        operationId = _executeTransferAssets(
            destinationChainId,
            asset,
            amount,
            recipient,
            originator, // Pass originator from queue call
            options,
            true // Indicate it IS a BridgeQueue call
        );
        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyBridgeQueue returns (bytes32 operationId) {
        operationId = _executeReadState(
            dstChainId,
            dstContract,
            selector,
            readParams,
            originator, // Originator for the *read operation itself* is the BridgeQueue
            options,
            true // Indicate it IS a BridgeQueue call
        );
        return operationId;
    }

    /**
     * @inheritdoc IBridgeRouter
     */
    function executeSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyBridgeQueue returns (bytes32 operationId) {
        operationId = _executeSendMessage(
            destinationChainId,
            recipient,
            message,
            originator, // Originator is the BridgeQueue
            options,
            true // Indicate it IS a BridgeQueue call
        );
        return operationId;
    }

    /**
     * @notice INTERNAL function to execute asset transfer operation.
     * @dev Centralizes validation, fee handling, and adapter interaction. NO access control here.
     *      Handles fee calculation based on whether the call originates from the user or the BridgeQueue.
     * @param destinationChainId ID of the destination chain.
     * @param asset Address of the asset to transfer.
     * @param amount Amount of the asset to transfer.
     * @param recipient Address of the recipient on the destination chain.
     * @param originator Original address that requested the transfer.
     * @param options Additional options for the transfer.
     * @param isBridgeQueueCall True if called by BridgeQueue, false if called internally by user-facing functions.
     * @return operationId Unique ID to track this transfer.
     */
    function _executeTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        address originator,
        BridgeTypes.BridgeOptions calldata options,
        bool isBridgeQueueCall
    ) internal returns (bytes32 operationId) {
        // Validations
        if (paused) revert Paused();
        if (amount == 0 || recipient == address(0) || originator == address(0))
            revert InvalidParams();

        // Determine if multiplier should be applied (only for user calls, not queue calls)
        bool applyMultiplier = !isBridgeQueueCall;

        // Get required fee (total or base) and selected adapter
        (uint256 requiredNativeFee, , address selectedAdapter) = _quote(
            destinationChainId,
            asset,
            amount,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET,
            applyMultiplier
        );

        // Validate fee provided
        if (msg.value < requiredNativeFee) revert InsufficientFee();

        // Refund excess fee to the original sender (originator)
        if (msg.value > requiredNativeFee) {
            (bool success, ) = originator.call{
                value: msg.value - requiredNativeFee
            }("");
            if (!success) revert TransferFailed(); // Consider implications of refund failure
        }

        // Determine the base fee to send to the adapter
        uint256 baseFeeToSend;
        if (applyMultiplier) {
            // Called by user, need to calculate base fee from total required fee
            if (feeMultiplier == 0) revert InvalidFeeMultiplier();
            baseFeeToSend = (requiredNativeFee * 100) / feeMultiplier;
            // Recalculate base fee if rounding resulted in 0 but required fee > 0
            if (baseFeeToSend == 0 && requiredNativeFee > 0) {
                (uint256 baseNativeFeeFromAdapter, ) = IBridgeAdapter(
                    selectedAdapter
                ).estimateFee(
                        destinationChainId,
                        asset,
                        amount,
                        options.adapterParams,
                        BridgeTypes.OperationType.TRANSFER_ASSET
                    );
                baseFeeToSend = baseNativeFeeFromAdapter;
                // Ensure at least 1 wei is sent if original required fee was non-zero
                if (baseFeeToSend == 0 && requiredNativeFee > 0)
                    baseFeeToSend = 1;
            }
        } else {
            // Called by BridgeQueue, required fee is already the base fee
            baseFeeToSend = requiredNativeFee;
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();
        if (!IBridgeAdapter(selectedAdapter).supportsAssetTransfer()) {
            revert UnsupportedAdapterOperation();
        }

        // Approve the adapter to spend the tokens
        IERC20(asset).approve(selectedAdapter, 0); // Reset approval first
        IERC20(asset).approve(selectedAdapter, amount);

        // Call the adapter to perform the transfer
        operationId = IBridgeAdapter(selectedAdapter).transferAsset{
            value: baseFeeToSend
        }( // Send the calculated base fee
            destinationChainId,
            asset,
            recipient,
            amount,
            originator, // Pass originator to the adapter
            options.adapterParams
        );

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationToAdapter[operationId] = selectedAdapter;

        emit TransferInitiated(
            operationId,
            destinationChainId,
            asset,
            amount,
            recipient,
            selectedAdapter
        );

        return operationId;
    }

    /**
     * @notice INTERNAL function to execute cross-chain read state operation.
     * @dev Centralizes validation, fee handling, and adapter interaction. NO access control here.
     *      Handles fee calculation based on whether the call originates from the user or the BridgeQueue.
     * @param dstChainId ID of the destination chain.
     * @param dstContract Address of the contract on the destination chain to read from.
     * @param selector Function selector to call.
     * @param readParams Parameters for the function call.
     * @param originator Original address that requested the read.
     * @param options Additional options for the read operation.
     * @param applyMultiplier True if called by BridgeQueue, false if called internally by user-facing functions.
     * @return operationId Unique ID to track this read operation.
     */
    function _executeReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.BridgeOptions calldata options,
        bool applyMultiplier
    ) internal returns (bytes32 operationId) {
        // Validations
        if (paused) revert Paused();
        if (originator == address(0) || dstContract == address(0))
            revert InvalidParams();

        // Get required fee (total or base) and selected adapter
        (uint256 requiredNativeFee, , address selectedAdapter) = _quote(
            dstChainId,
            address(0), // No asset
            0, // No amount
            options,
            BridgeTypes.OperationType.READ_STATE,
            applyMultiplier
        );

        // Validate fee provided
        if (msg.value < requiredNativeFee) revert InsufficientFee();

        // Refund excess fee to the original sender (originator)
        if (msg.value > requiredNativeFee) {
            (bool success, ) = originator.call{
                value: msg.value - requiredNativeFee
            }("");
            if (!success) revert TransferFailed(); // Consider implications
        }

        // Determine the base fee to send to the adapter
        uint256 baseFeeToSend;
        if (applyMultiplier) {
            // Called by user, calculate base fee
            if (feeMultiplier == 0) revert InvalidFeeMultiplier();
            baseFeeToSend = (requiredNativeFee * 100) / feeMultiplier;
            if (baseFeeToSend == 0 && requiredNativeFee > 0) {
                // Recalculate base fee directly if rounding resulted in 0
                (uint256 baseNativeFeeFromAdapter, ) = IBridgeAdapter(
                    selectedAdapter
                ).estimateFee(
                        dstChainId,
                        address(0),
                        0,
                        options.adapterParams,
                        BridgeTypes.OperationType.READ_STATE
                    );
                baseFeeToSend = baseNativeFeeFromAdapter;
                if (baseFeeToSend == 0 && requiredNativeFee > 0)
                    baseFeeToSend = 1; // Safety net
            }
        } else {
            // Called by BridgeQueue, required fee is the base fee
            baseFeeToSend = requiredNativeFee;
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports state reads
        if (!IBridgeAdapter(selectedAdapter).supportsStateRead()) {
            revert UnsupportedAdapterOperation();
        }

        // Call the adapter with the calculated base fee
        operationId = IBridgeAdapter(selectedAdapter).readState{
            value: baseFeeToSend
        }(
            uint16(block.chainid), // Source chain ID
            dstChainId,
            dstContract,
            selector,
            readParams,
            originator, // Pass originator to adapter
            options.adapterParams
        );

        // Store the originator for response delivery
        readRequestToOriginator[operationId] = originator;

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationToAdapter[operationId] = selectedAdapter;

        emit ReadRequestInitiated(
            operationId,
            dstChainId,
            dstContract,
            selector,
            readParams,
            selectedAdapter
        );

        return operationId;
    }

    /**
     * @notice INTERNAL function to execute cross-chain message send operation.
     * @dev Centralizes validation, fee handling, and adapter interaction. NO access control here.
     *      Handles fee calculation based on whether the call originates from the user or the BridgeQueue.
     * @param destinationChainId ID of the destination chain.
     * @param recipient Address of the recipient on the destination chain.
     * @param message The message data to be sent cross-chain.
     * @param originator Original address that requested the message send.
     * @param options Additional options for the message.
     * @param isBridgeQueueCall True if called by BridgeQueue, false if called internally by user-facing functions.
     * @return operationId Unique ID to track this message.
     */
    function _executeSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.BridgeOptions calldata options,
        bool isBridgeQueueCall
    ) internal returns (bytes32 operationId) {
        // Validations
        if (paused) revert Paused();
        if (recipient == address(0) || originator == address(0))
            revert InvalidParams();

        // Determine if multiplier should be applied
        bool applyMultiplier = !isBridgeQueueCall;

        // Get required fee (total or base) and selected adapter
        (uint256 requiredNativeFee, , address selectedAdapter) = _quote(
            destinationChainId,
            address(0), // No asset
            0, // No amount
            options,
            BridgeTypes.OperationType.MESSAGE,
            applyMultiplier
        );

        // Validate fee provided
        if (msg.value < requiredNativeFee) revert InsufficientFee();

        // Refund excess fee to the original sender (originator)
        if (msg.value > requiredNativeFee) {
            (bool success, ) = originator.call{
                value: msg.value - requiredNativeFee
            }("");
            if (!success) revert TransferFailed(); // Consider implications
        }

        // Determine the base fee to send to the adapter
        uint256 baseFeeToSend;
        if (applyMultiplier) {
            // Called by user, calculate base fee
            if (feeMultiplier == 0) revert InvalidFeeMultiplier();
            baseFeeToSend = (requiredNativeFee * 100) / feeMultiplier;
            if (baseFeeToSend == 0 && requiredNativeFee > 0) {
                // Recalculate base fee directly if rounding resulted in 0
                (uint256 baseNativeFeeFromAdapter, ) = IBridgeAdapter(
                    selectedAdapter
                ).estimateFee(
                        destinationChainId,
                        address(0),
                        0,
                        options.adapterParams,
                        BridgeTypes.OperationType.MESSAGE
                    );
                baseFeeToSend = baseNativeFeeFromAdapter;
                if (baseFeeToSend == 0 && requiredNativeFee > 0)
                    baseFeeToSend = 1; // Safety net
            }
        } else {
            // Called by BridgeQueue, required fee is the base fee
            baseFeeToSend = requiredNativeFee;
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports messaging
        if (!IBridgeAdapter(selectedAdapter).supportsMessaging()) {
            revert UnsupportedAdapterOperation();
        }

        // Call the adapter with the calculated base fee
        operationId = ISendAdapter(selectedAdapter).sendMessage{
            value: baseFeeToSend
        }(
            destinationChainId,
            recipient,
            message,
            originator, // Pass originator to adapter
            options.adapterParams
        );

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationToAdapter[operationId] = selectedAdapter;

        emit MessageInitiated(
            operationId,
            destinationChainId,
            recipient,
            selectedAdapter
        );

        return operationId;
    }
}
