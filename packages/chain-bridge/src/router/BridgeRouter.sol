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

    /// @notice Standard gas limit for confirmation transactions
    uint64 public confirmationGasLimit = 200000; // Default reasonable gas limit for confirmations

    /// @notice Mapping of chain IDs to their BridgeRouter addresses
    mapping(uint16 chainId => address routerAddress)
        public chainToRouterAddress;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BridgeRouter contract
     * @param accessManager Address of the ProtocolAccessManager contract
     * @param chainIds Array of chain IDs to configure
     * @param routerAddresses Array of corresponding router addresses
     */
    constructor(
        address accessManager,
        uint16[] memory chainIds,
        address[] memory routerAddresses
    ) ProtocolAccessManaged(accessManager) {
        if (chainIds.length != routerAddresses.length) revert InvalidParams();

        // Set up initial chain-to-router mappings
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (routerAddresses[i] != address(0)) {
                chainToRouterAddress[chainIds[i]] = routerAddresses[i];
                emit ChainRouterAddressUpdated(chainIds[i], routerAddresses[i]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal implementation of quote that handles adapter selection and fee calculation
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param options Additional options for the transfer
     * @param operationType Type of operation being performed
     * @return nativeFee Fee in native token
     * @return tokenFee Fee in the asset token
     * @return selectedAdapter Address of the selected adapter
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
        // Select adapter - either user specified or best available
        selectedAdapter = options.specifiedAdapter;

        if (selectedAdapter != address(0)) {
            // Verify the specified adapter is registered
            if (!adapters.contains(selectedAdapter)) revert UnknownAdapter();

            // Verify adapter supports the required operation
            if (
                operationType == BridgeTypes.OperationType.TRANSFER_ASSET &&
                !IBridgeAdapter(selectedAdapter).supportsAssetTransfer()
            ) revert UnsupportedAdapterOperation();

            if (
                operationType == BridgeTypes.OperationType.READ_STATE &&
                !IBridgeAdapter(selectedAdapter).supportsStateRead()
            ) revert UnsupportedAdapterOperation();

            if (!IBridgeAdapter(selectedAdapter).supportsMessaging())
                revert UnsupportedAdapterOperation();
        } else {
            // Find the best adapter based on operation type
            selectedAdapter = getBestAdapter(
                destinationChainId,
                asset,
                amount,
                operationType
            );
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Get base fee from adapter
        (uint256 baseFee, uint256 baseTokenFee) = IBridgeAdapter(
            selectedAdapter
        ).estimateFee(
                destinationChainId,
                asset,
                amount,
                options.adapterParams,
                operationType
            );

        // Apply fee multiplier for both native and token fees
        nativeFee = (baseFee * feeMultiplier) / 100;
        tokenFee = (baseTokenFee * feeMultiplier) / 100;

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

        // Get the total fee and base fee with proper operation type
        (uint256 totalFee, , ) = _quote(
            destinationChainId,
            asset,
            amount,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
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
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId) {
        if (paused) revert Paused();

        // Select the adapter - must use specifiedAdapter if provided
        address adapter = options.specifiedAdapter;
        if (adapter == address(0)) {
            adapter = getBestAdapterForStateRead(dstChainId);
        }

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports state reads
        if (!IBridgeAdapter(adapter).supportsStateRead()) {
            revert UnsupportedAdapterOperation();
        }

        // Get the total fee using our internal function with READ_STATE type
        (uint256 totalFee, , ) = _quote(
            dstChainId,
            address(0), // No asset for state reads
            0, // No amount for state reads
            options,
            BridgeTypes.OperationType.READ_STATE
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
            dstChainId,
            dstContract,
            selector,
            readParams,
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
            dstChainId,
            dstContract,
            selector,
            readParams,
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

        // Get the total fee and base fee with proper operation type
        (uint256 totalFee, , ) = _quote(
            destinationChainId,
            address(0),
            0,
            options,
            BridgeTypes.OperationType.MESSAGE
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

    /// @inheritdoc IBridgeRouter
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
     * @notice Finds the best adapter for an operation based on both compatibility and cost
     * @param chainId Destination or source chain ID
     * @param asset Asset to send (address(0) for non-asset operations)
     * @param amount Amount to transfer (0 for non-asset operations)
     * @param operationType Type of operation to perform
     * @return The address of the lowest-cost suitable adapter
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
                        gasLimit: 200000,
                        calldataSize: 100,
                        msgValue: 0,
                        options: ""
                    }),
                    operationType // Pass the operation type directly
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
}
