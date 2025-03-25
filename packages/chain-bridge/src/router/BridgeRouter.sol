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

    /// @notice Mapping of transfer IDs to their current status
    mapping(bytes32 transferId => BridgeTypes.TransferStatus status)
        public transferStatuses;

    /// @notice Mapping of transfer IDs to the adapter that processed them
    mapping(bytes32 transferId => address adapter) public transferToAdapter;

    /// @notice Mapping to track read request originators
    mapping(bytes32 requestId => address originator)
        public readRequestToOriginator;

    /// @notice Pause state of the router
    bool public paused;

    /// @notice Add a new mapping to track confirmation statuses
    mapping(bytes32 transferId => bool confirmed) public confirmationSent;

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
    ) external payable returns (bytes32 transferId) {
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

        // Calculate base fee (without multiplier)
        (uint256 baseFee, ) = IBridgeAdapter(adapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options.adapterParams
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
        transferId = IBridgeAdapter(adapter).transferAsset{value: baseFee}(
            destinationChainId,
            asset,
            recipient,
            amount,
            msg.sender, // Pass the originator for refunds
            options.adapterParams
        );

        // Update state
        transferStatuses[transferId] = BridgeTypes.TransferStatus.PENDING;
        transferToAdapter[transferId] = adapter;

        emit TransferInitiated(
            transferId,
            destinationChainId,
            asset,
            amount,
            recipient,
            adapter
        );

        return transferId;
    }

    /// @inheritdoc IBridgeRouter
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 requestId) {
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
        requestId = IBridgeAdapter(adapter).readState{value: baseFee}(
            sourceChainId,
            sourceContract,
            selector,
            params,
            msg.sender, // Pass the originator for refunds
            options.adapterParams
        );

        // Store the originator of this request
        readRequestToOriginator[requestId] = msg.sender;

        // Update state
        transferStatuses[requestId] = BridgeTypes.TransferStatus.PENDING;
        transferToAdapter[requestId] = adapter;

        emit ReadRequestInitiated(
            requestId,
            sourceChainId,
            abi.encodePacked(sourceContract),
            selector,
            params,
            adapter
        );

        return requestId;
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
    function updateTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external onlyRegisteredAdapter {
        if (transferToAdapter[transferId] != msg.sender) revert Unauthorized();

        transferStatuses[transferId] = status;
        emit TransferStatusUpdated(transferId, status);
    }

    /// @inheritdoc IBridgeRouter
    function deliverReadResponse(
        bytes32 requestId,
        bytes calldata resultData
    ) external onlyRegisteredAdapter {
        if (transferToAdapter[requestId] != msg.sender) revert Unauthorized();

        address originator = readRequestToOriginator[requestId];
        if (originator == address(0)) revert InvalidParams();

        // Update status
        transferStatuses[requestId] = BridgeTypes.TransferStatus.DELIVERED;

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
                        requestId
                    )
                {} catch {
                    revert ReceiverRejectedCall();
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
                        requestId
                    )
                );
                if (!success) revert ReceiverRejectedCall();
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
                    requestId
                )
            );
            if (!success) revert ReceiverRejectedCall();
        }

        emit ReadRequestStatusUpdated(
            requestId,
            BridgeTypes.TransferStatus.DELIVERED
        );
    }

    /// @inheritdoc IBridgeRouter
    function deliverMessage(
        bytes32 messageId,
        bytes memory message,
        address recipient
    ) external onlyRegisteredAdapter {
        if (transferToAdapter[messageId] != msg.sender) revert Unauthorized();

        // Update status
        transferStatuses[messageId] = BridgeTypes.TransferStatus.DELIVERED;

        // Try to deliver the message to the recipient
        bytes4 interfaceId = type(ICrossChainReceiver).interfaceId;
        try
            ICrossChainReceiver(recipient).supportsInterface(interfaceId)
        returns (bool supported) {
            if (supported) {
                ICrossChainReceiver(recipient).receiveMessage(
                    message,
                    recipient,
                    0, // sourceChainId (could be added as a parameter)
                    messageId
                );
            } else {
                // Fallback for contracts that don't implement supportsInterface
                (bool success, ) = recipient.call(
                    abi.encodeWithSelector(
                        ICrossChainReceiver.receiveMessage.selector,
                        message,
                        recipient,
                        0, // sourceChainId
                        messageId
                    )
                );
                if (!success) revert("Receiver rejected call");
            }
        } catch {
            // Fallback for contracts that don't implement supportsInterface
            (bool success, ) = recipient.call(
                abi.encodeWithSelector(
                    ICrossChainReceiver.receiveMessage.selector,
                    message,
                    recipient,
                    0, // sourceChainId
                    messageId
                )
            );
            if (!success) revert("Receiver rejected call");
        }

        emit TransferStatusUpdated(
            messageId,
            BridgeTypes.TransferStatus.DELIVERED
        );
    }

    /// @inheritdoc IBridgeRouter
    function notifyTransferReceived(
        bytes32 transferId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) external onlyRegisteredAdapter nonReentrant {
        if (transferToAdapter[transferId] != msg.sender) revert Unauthorized();

        // Update status locally (in case this is tracking a return transfer)
        if (transferToAdapter[transferId] == msg.sender) {
            transferStatuses[transferId] = BridgeTypes.TransferStatus.DELIVERED;
            emit TransferStatusUpdated(
                transferId,
                BridgeTypes.TransferStatus.DELIVERED
            );
        }

        // Emit event for the received transfer
        emit TransferReceived(
            transferId,
            asset,
            amount,
            recipient,
            sourceChainId
        );

        // Find confirmation adapter
        address confirmationAdapter = getBestAdapter(
            sourceChainId,
            address(0), // No specific asset for confirmation
            0 // No specific amount
        );

        if (
            confirmationAdapter != address(0) &&
            IBridgeAdapter(confirmationAdapter).supportsMessaging()
        ) {
            // Encode the confirmation message
            bytes memory confirmationMessage = abi.encode(
                transferId,
                BridgeTypes.TransferStatus.DELIVERED
            );

            // We don't use _quote here because:
            // 1. This is already the "confirmation" part that the fee multiplier paid for
            // 2. We're paying from the router's balance, not collecting from a user
            // 3. We don't need to reserve funds for another confirmation

            // Use the correct parameter format for estimateFee
            (uint256 confirmationFee, ) = IBridgeAdapter(confirmationAdapter)
                .estimateFee(
                    sourceChainId,
                    address(0), // No asset for confirmation message
                    0, // No amount for confirmation message
                    BridgeTypes.AdapterParams({
                        gasLimit: 100000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                );

            // Send confirmation using router's accumulated balance
            try
                ISendAdapter(confirmationAdapter).sendMessage{
                    value: confirmationFee
                }(
                    sourceChainId,
                    address(this), // Target is the BridgeRouter on the source chain
                    confirmationMessage,
                    address(0), // No refund address needed
                    BridgeTypes.AdapterParams({
                        gasLimit: 100000,
                        msgValue: 0,
                        calldataSize: 0,
                        options: ""
                    })
                )
            returns (bytes32) {
                confirmationSent[transferId] = true;
            } catch {
                emit ConfirmationFailed(transferId);
            }
        }
    }

    /// @notice Receive confirmation messages from adapters
    function receiveConfirmation(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external onlyRegisteredAdapter {
        // Only update status in forward progression (pending->complete, not complete->pending)
        if (_isStatusProgression(transferStatuses[transferId], status)) {
            transferStatuses[transferId] = status;
            emit TransferStatusUpdated(transferId, status);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the best adapter for a specific operation type
     * @param chainId Destination chain ID
     * @param asset Asset to transfer (set to address(0) for non-asset operations)
     * @param requiresAssetTransfer Whether the operation requires asset transfer support
     * @param requiresMessaging Whether the operation requires messaging support
     * @param requiresStateRead Whether the operation requires state read support
     * @return The address of the best suitable adapter
     */
    function _getBestAdapterForOperation(
        uint16 chainId,
        address asset,
        bool requiresAssetTransfer,
        bool requiresMessaging,
        bool requiresStateRead
    ) internal view returns (address) {
        address bestAdapter = address(0);

        uint256 adapterCount = adapters.length();
        for (uint256 i = 0; i < adapterCount; i++) {
            address adapter = adapters.at(i);

            // Check if adapter supports this chain
            if (!IBridgeAdapter(adapter).supportsChain(chainId)) continue;

            // Check capability requirements
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
                !IBridgeAdapter(adapter).supportsAsset(chainId, asset)
            ) continue;

            // Found a suitable adapter
            bestAdapter = adapter;
            break;
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
    function getTransferStatus(
        bytes32 transferId
    ) external view returns (BridgeTypes.TransferStatus) {
        return transferStatuses[transferId];
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
     * @param currentStatus The current status of the transfer
     * @param newStatus The proposed new status
     * @return True if the status change is valid forward progression
     */
    function _isStatusProgression(
        BridgeTypes.TransferStatus currentStatus,
        BridgeTypes.TransferStatus newStatus
    ) internal pure returns (bool) {
        // Failed is a terminal state, can't progress from it
        if (currentStatus == BridgeTypes.TransferStatus.FAILED) {
            return false;
        }

        // Completed is a terminal state, can't progress from it
        if (currentStatus == BridgeTypes.TransferStatus.COMPLETED) {
            return false;
        }

        // Can always progress to FAILED from any non-terminal state
        if (newStatus == BridgeTypes.TransferStatus.FAILED) {
            return true;
        }

        // Status progression order: PENDING -> DELIVERED -> COMPLETED
        if (currentStatus == BridgeTypes.TransferStatus.PENDING) {
            return
                newStatus == BridgeTypes.TransferStatus.DELIVERED ||
                newStatus == BridgeTypes.TransferStatus.COMPLETED;
        }

        if (currentStatus == BridgeTypes.TransferStatus.DELIVERED) {
            return newStatus == BridgeTypes.TransferStatus.COMPLETED;
        }

        // Default: no progression
        return false;
    }

    /**
     * @notice Allows recovery of transfers when automated confirmations fail
     * @param transferId ID of the transfer to update
     * @param status New status to set
     * @dev Can only be called by authorized keepers or governance
     */
    function recoverTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external onlyGuardianOrGovernor {
        // Check if the transfer exists
        if (transferToAdapter[transferId] == address(0)) revert InvalidParams();

        // Only allow status updates in forward progression
        if (!_isStatusProgression(transferStatuses[transferId], status)) {
            revert InvalidStatusProgression();
        }

        // Update the status
        transferStatuses[transferId] = status;
        emit TransferStatusUpdated(transferId, status);
        emit ManualStatusUpdate(transferId, status, msg.sender);
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
