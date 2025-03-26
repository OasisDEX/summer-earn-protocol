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
    mapping(bytes32 operationId => address adapter) public operationToAdapter;

    /// @notice Mapping of request IDs to the adapter that processed them
    mapping(bytes32 requestId => address adapter)
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

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BridgeRouter contract
     * @param accessManager Address of the ProtocolAccessManager contract
     */
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {}

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal implementation of quote that can reuse a selected adapter
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param options Additional options for the transfer
     * @param preselectedAdapter Optional adapter address (if already selected)
     * @return nativeFee Fee in native token
     * @return tokenFee Fee in the asset token
     * @return selectedAdapter Address of the selected adapter
     */
    function _quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions memory options,
        address preselectedAdapter
    )
        internal
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        selectedAdapter = preselectedAdapter;
        if (selectedAdapter == address(0)) {
            selectedAdapter = getBestAdapter(destinationChainId, asset, amount);
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Get base fee from adapter
        (uint256 baseFee, ) = IBridgeAdapter(selectedAdapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options.adapterParams
        );

        // Apply multiplier to account for confirmation
        nativeFee = (baseFee * feeMultiplier) / 100;

        return (nativeFee, tokenFee, selectedAdapter);
    }

    /// @inheritdoc IBridgeRouter
    function quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter)
    {
        return _quote(destinationChainId, asset, amount, options, address(0));
    }

    /// @inheritdoc IBridgeRouter
    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId) {
        if (paused) revert Paused();
        if (amount == 0 || recipient == address(0)) revert InvalidParams();

        // Use specified adapter or find the best one
        address adapter = options.specifiedAdapter;
        if (adapter == address(0)) {
            adapter = getBestAdapter(destinationChainId, asset, amount);
        } else if (!adapters.contains(adapter)) {
            revert UnknownAdapter();
        }

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports asset transfers
        if (!IBridgeAdapter(adapter).supportsAssetTransfer()) {
            revert UnsupportedAdapterOperation();
        }

        // Get the total fee and base fee using our internal function with the selected adapter
        (uint256 totalFee, , ) = _quote(
            destinationChainId,
            asset,
            amount,
            options,
            adapter
        );

        // Ensure user provided enough fee
        if (msg.value < totalFee) revert InsufficientFee();

        // Return any excess fee to the sender
        if (msg.value > totalFee) {
            (bool success, ) = msg.sender.call{value: msg.value - totalFee}("");
            if (!success) revert TransferFailed();
        }

        // Transfer tokens from sender to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve the adapter to spend the tokens - first reset allowance to 0
        IERC20(asset).approve(adapter, 0);
        IERC20(asset).approve(adapter, amount);

        // Only forward the base fee to the adapter, router keeps the rest for confirmation
        operationId = IBridgeAdapter(adapter).transferAsset{value: msg.value}(
            destinationChainId,
            asset,
            recipient,
            amount,
            msg.sender, // Pass the originator for refunds
            options.adapterParams
        );

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationToAdapter[operationId] = adapter;

        emit TransferInitiated(
            operationId,
            destinationChainId,
            asset,
            amount,
            recipient,
            adapter
        );

        return operationId;
    }

    /// @inheritdoc IBridgeRouter
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId) {
        if (paused) revert Paused();

        // Select the best adapter for this read request
        address adapter = options.specifiedAdapter;
        if (adapter == address(0)) {
            adapter = getBestAdapterForStateRead(sourceChainId);
        }

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports state reads
        if (!IBridgeAdapter(adapter).supportsStateRead()) {
            revert UnsupportedAdapterOperation();
        }

        // Get the total fee and base fee using our internal function
        (uint256 totalFee, , ) = _quote(
            sourceChainId,
            address(0), // No asset for state reads
            0, // No amount for state reads
            options,
            adapter
        );

        // Calculate base fee from total fee
        uint256 baseFee = (totalFee * 100) / feeMultiplier;

        // Ensure user provided enough fee
        if (msg.value < totalFee) revert InsufficientFee();

        // Return any excess fee to the sender
        if (msg.value > totalFee) {
            (bool success, ) = msg.sender.call{value: msg.value - totalFee}("");
            if (!success) revert TransferFailed();
        }

        // Let the adapter handle gas limits and other options
        // Pass msg.sender for refunds, but only forward the base fee
        operationId = IBridgeAdapter(adapter).readState{value: baseFee}(
            sourceChainId,
            sourceContract,
            selector,
            params,
            msg.sender, // Pass the originator for refunds
            options.adapterParams
        );

        // Store the originator of this request
        readRequestToOriginator[operationId] = msg.sender;

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationToAdapter[operationId] = adapter;

        emit ReadRequestInitiated(
            operationId,
            sourceChainId,
            abi.encodePacked(sourceContract),
            selector,
            params,
            adapter
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
        if (paused) revert Paused();
        if (recipient == address(0)) revert InvalidParams();

        // Use specified adapter or find the best one
        address adapter = options.specifiedAdapter;
        if (adapter == address(0)) {
            adapter = getBestAdapter(destinationChainId, address(0), 0);
        } else if (!adapters.contains(adapter)) {
            revert UnknownAdapter();
        }

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports messaging
        if (!IBridgeAdapter(adapter).supportsMessaging()) {
            revert UnsupportedAdapterOperation();
        }

        // Get the total fee and base fee
        (uint256 totalFee, , ) = _quote(
            destinationChainId,
            address(0),
            0,
            options,
            adapter
        );

        // Ensure user provided enough fee
        if (msg.value < totalFee) revert InsufficientFee();

        // Return any excess fee to the sender
        if (msg.value > totalFee) {
            (bool success, ) = msg.sender.call{value: msg.value - totalFee}("");
            if (!success) revert TransferFailed();
        }

        // Calculate base fee from total fee
        uint256 baseFee = (totalFee * 100) / feeMultiplier;

        // Send the message through the selected adapter
        operationId = ISendAdapter(adapter).sendMessage{value: baseFee}(
            destinationChainId,
            recipient,
            message,
            msg.sender, // Pass the originator for refunds
            options.adapterParams
        );

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.PENDING;
        operationToAdapter[operationId] = adapter;

        emit MessageInitiated(
            operationId,
            destinationChainId,
            recipient,
            adapter
        );

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensure adapter is registered
    modifier onlyRegisteredAdapter() {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
        _;
    }

    /// @inheritdoc IBridgeRouter
    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external onlyRegisteredAdapter {
        if (operationToAdapter[operationId] != msg.sender)
            revert Unauthorized();

        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
    }

    function updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    ) external onlyRegisteredAdapter {
        requestReceivedByAdapter[requestId] = msg.sender;

        // Update the status
        operationStatuses[requestId] = status;
        emit OperationStatusUpdated(requestId, status);

        if (status != BridgeTypes.OperationStatus.DELIVERED) {
            emit MessageDelivered(requestId, recipient, false);
        }
    }

    // @inheritdoc IBridgeRouter
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
                // Convert our status type to bytes that can be sent as a message
                ISendAdapter(msg.sender).sendMessage(
                    sourceChainId,
                    address(this), // Target is the BridgeRouter on the source chain
                    abi.encode(
                        operationId,
                        BridgeTypes.OperationStatus.DELIVERED
                    ),
                    address(0), // No refund address needed
                    BridgeTypes.AdapterParams({
                        gasLimit: 100000, // TODO: Use min gas limits for this kind of action
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

    /// @notice Receive confirmation messages from adapters
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
     * @notice Finds the best adapter for an operation based on both compatibility and cost
     * @param chainId Destination or source chain ID
     * @param asset Asset to send (address(0) for non-asset operations)
     * @param requiresAssetTransfer Whether asset transfer support is required
     * @param requiresMessaging Whether messaging support is required
     * @param requiresStateRead Whether state read support is required
     * @return The address of the lowest-cost suitable adapter
     */
    function _getBestAdapterForOperation(
        uint16 chainId,
        address asset,
        bool requiresAssetTransfer,
        bool requiresMessaging,
        bool requiresStateRead
    ) internal view returns (address) {
        address bestAdapter = address(0);
        uint256 lowestFee = type(uint256).max;

        uint256 adapterCount = adapters.length();
        for (uint256 i = 0; i < adapterCount; i++) {
            address adapter = adapters.at(i);

            // Check if adapter supports this chain
            if (!IBridgeAdapter(adapter).supportsChain(chainId)) continue;

            // Check for operation-specific support
            if (
                requiresAssetTransfer &&
                !IBridgeAdapter(adapter).supportsAssetTransfer()
            ) continue;
            if (
                requiresMessaging &&
                !IBridgeAdapter(adapter).supportsMessaging()
            ) continue;
            if (
                requiresStateRead &&
                !IBridgeAdapter(adapter).supportsStateRead()
            ) continue;

            // For asset transfers, check if the asset is supported
            if (
                asset != address(0) &&
                requiresAssetTransfer &&
                !IBridgeAdapter(adapter).supportsAsset(chainId, asset)
            ) continue;

            // If we get here, the adapter is suitable, so check its fee
            uint256 estimatedFee = 0;

            try
                IBridgeAdapter(adapter).estimateFee(
                    chainId,
                    asset,
                    requiresAssetTransfer ? 1 ether : 0, // Use 1 ETH as a standard amount for comparison
                    BridgeTypes.AdapterParams({
                        gasLimit: 500000,
                        calldataSize: 0,
                        msgValue: 0,
                        options: ""
                    })
                )
            returns (uint256 fee, uint256) {
                estimatedFee = fee;
            } catch {
                // If estimation fails, consider this adapter more expensive
                estimatedFee = type(uint256).max;
            }

            // Apply router's fee multiplier to get total cost
            uint256 totalFee = (estimatedFee * feeMultiplier) / 100;

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
        bool forStateRead
    ) public view returns (address) {
        // Determine operation type based on parameters
        bool isAssetTransfer = asset != address(0) && amount > 0;

        return
            _getBestAdapterForOperation(
                chainId,
                asset,
                isAssetTransfer && !forStateRead, // Asset transfer only if not for state read
                true, // All operations require basic messaging
                forStateRead // State read required only if specified
            );
    }

    /// @inheritdoc IBridgeRouter
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount
    ) public view returns (address) {
        // Default to non-state read operation
        return getBestAdapter(chainId, asset, amount, false);
    }

    /// @notice Get the best adapter for state read operations
    /// @param chainId Source chain ID to read from
    /// @return The address of the best adapter for state reading
    function getBestAdapterForStateRead(
        uint16 chainId
    ) public view returns (address) {
        return getBestAdapter(chainId, address(0), 0, true);
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

    /**
     * @notice Checks if a status change represents forward progression
     * @param currentStatus The current status of the operation
     * @param newStatus The proposed new status
     * @return True if the status change is valid forward progression
     */
    function _isStatusProgression(
        BridgeTypes.OperationStatus currentStatus,
        BridgeTypes.OperationStatus newStatus
    ) internal pure returns (bool) {
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
     * @notice Allows recovery of operations when automated confirmations fail
     * @param operationId ID of the operation to update
     * @param status New status to set
     * @dev Can only be called by authorized keepers or governance
     */
    function recoverOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external onlyGuardianOrGovernor {
        // Check if the operation exists
        if (operationToAdapter[operationId] == address(0))
            revert InvalidParams();

        // Only allow status updates in forward progression
        if (!_isStatusProgression(operationStatuses[operationId], status)) {
            revert InvalidStatusProgression();
        }

        // Update the status
        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
        emit ManualStatusUpdate(operationId, status, msg.sender);
    }

    /**
     * @notice Update the fee multiplier
     * @param multiplier New multiplier (200 = 200% = double fee)
     */
    function setFeeMultiplier(uint256 multiplier) external onlyGovernor {
        feeMultiplier = multiplier;
    }

    /**
     * @notice Allows governance to withdraw native tokens from the contract
     * @param recipient Address to send tokens to
     * @param amount Amount to withdraw
     */
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

    /**
     * @notice Allow anyone to fund the router with native tokens for confirmations
     */
    function addRouterFunds() external payable {
        emit RouterFundsAdded(msg.sender, msg.value);
    }

    // Add a function to check current router balance
    function getRouterBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
