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

    /// @notice Default gas limit to use when estimating adapter fees
    uint64 public DEFAULT_GAS_LIMIT = 200000;

    /// @notice Default calldata size to use when estimating adapter fees
    uint32 internal constant DEFAULT_CALLDATA_SIZE = 100;

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
        bridgeQueue = _bridgeQueue;
        emit BridgeQueueUpdated(_bridgeQueue);

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
                           BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

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
     * @inheritdoc IBridgeRouter
     */
    function executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params
    )
        external
        payable
        onlyBridgeQueue
        nonReentrant
        returns (bytes32 operationId)
    {
        // Validations
        if (paused) revert Paused();
        if (
            params.amount == 0 ||
            params.recipient == address(0) ||
            params.originator == address(0)
        ) revert InvalidParams();
        if (params.asset == address(0)) revert InvalidParams(); // Ensure asset is specified for transfers

        // Get required base fee and selected adapter (no multiplier)
        (uint256 requiredBaseFee, , address selectedAdapter) = _quote(
            params.destinationChainId,
            params.asset,
            params.amount,
            params.options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Validate fee provided by BridgeQueue
        if (msg.value < requiredBaseFee) revert InsufficientFee();

        // Use the base fee required by the adapter
        uint256 baseFeeToSend = requiredBaseFee;

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();
        if (!IBridgeAdapter(selectedAdapter).supportsAssetTransfer()) {
            revert UnsupportedAdapterOperation();
        }

        // Assuming the BridgeQueue has already ensured the Router has the necessary tokens.
        // Approve the adapter to spend the Router's tokens.
        IERC20(params.asset).approve(selectedAdapter, 0); // Reset approval first
        IERC20(params.asset).approve(selectedAdapter, params.amount);

        // Call the adapter to perform the transfer
        operationId = IBridgeAdapter(selectedAdapter).transferAsset{
            value: baseFeeToSend
        }( // Send the exact base fee
            params.destinationChainId,
            params.asset,
            params.recipient,
            params.amount,
            params.originator, // Pass originator to the adapter
            params.options.adapterParams
        );

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationToAdapter[operationId] = selectedAdapter;

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
        nonReentrant
        returns (bytes32 operationId)
    {
        // Validations
        if (paused) revert Paused();
        if (params.originator == address(0) || params.dstContract == address(0))
            revert InvalidParams();

        // Get required base fee and selected adapter (no multiplier)
        (uint256 requiredBaseFee, , address selectedAdapter) = _quote(
            params.dstChainId,
            address(0), // No asset
            0, // No amount
            params.options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Validate fee provided by BridgeQueue
        if (msg.value < requiredBaseFee) revert InsufficientFee();

        // Use the base fee required by the adapter
        uint256 baseFeeToSend = requiredBaseFee;

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports state reads
        if (!IBridgeAdapter(selectedAdapter).supportsStateRead()) {
            revert UnsupportedAdapterOperation();
        }

        // Call the adapter with the base fee
        operationId = IBridgeAdapter(selectedAdapter).readState{
            value: baseFeeToSend
        }(
            uint16(block.chainid), // Source chain ID
            params.dstChainId,
            params.dstContract,
            params.selector,
            params.readParams,
            params.originator, // Pass originator to adapter
            params.options.adapterParams
        );

        // Store the originator for response delivery
        readRequestToOriginator[operationId] = params.originator;

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationToAdapter[operationId] = selectedAdapter;

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
        nonReentrant
        returns (bytes32 operationId)
    {
        // Validations
        if (paused) revert Paused();
        if (params.recipient == address(0) || params.originator == address(0))
            revert InvalidParams();

        // Get required base fee and selected adapter (no multiplier)
        (uint256 requiredBaseFee, , address selectedAdapter) = _quote(
            params.destinationChainId,
            address(0), // No asset
            0, // No amount
            params.options,
            BridgeTypes.OperationType.MESSAGE
        );

        // Validate fee provided by BridgeQueue
        if (msg.value < requiredBaseFee) revert InsufficientFee();

        // Use the base fee required by the adapter
        uint256 baseFeeToSend = requiredBaseFee;

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        // Check if adapter supports messaging
        if (!IBridgeAdapter(selectedAdapter).supportsMessaging()) {
            revert UnsupportedAdapterOperation();
        }

        // Call the adapter with the base fee
        operationId = ISendAdapter(selectedAdapter).sendMessage{
            value: baseFeeToSend
        }(
            params.destinationChainId,
            params.recipient,
            params.message,
            params.originator, // Pass originator to adapter
            params.options.adapterParams
        );

        // Update state
        operationStatuses[operationId] = BridgeTypes.OperationStatus.SENT;
        operationToAdapter[operationId] = selectedAdapter;

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
            // Finding the best adapter based on base fees
            selectedAdapter = _getBestAdapterForOperation(
                destinationChainId,
                asset,
                amount,
                operationType
            );
        }

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

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
    ) external onlyRegisteredAdapter {
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

    /**
     * @notice Finds the best adapter for an operation based on compatibility and estimated base fee.
     * @param chainId Destination or source chain ID.
     * @param asset Asset to send (address(0) for non-asset operations).
     * @param amount Amount to transfer (0 for non-asset operations).
     * @param operationType Type of operation to perform.
     * @return The address of the lowest-cost suitable adapter based on base fee.
     * @dev Considers chain support, operation support, asset support (if applicable), and estimated base fees.
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
                        gasLimit: DEFAULT_GAS_LIMIT, // Use constant default
                        calldataSize: DEFAULT_CALLDATA_SIZE, // Use constant default
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

            // Compare based on the estimated fee
            if (estimatedFee < lowestFee) {
                lowestFee = estimatedFee;
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
    function setDefaultGasLimit(uint256 newGasLimit) external onlyGovernor {
        DEFAULT_GAS_LIMIT = uint64(newGasLimit);
        emit DefaultGasLimitUpdated(newGasLimit);
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
