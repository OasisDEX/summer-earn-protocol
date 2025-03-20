// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IReceiveAdapter} from "../interfaces/IReceiveAdapter.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters
 */
contract BridgeRouter is IBridgeRouter, ProtocolAccessManaged {
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

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new adapter is registered
    event AdapterRegistered(address indexed adapter);

    /// @notice Emitted when an adapter is removed
    event AdapterRemoved(address indexed adapter);

    /// @notice Emitted when a transfer is initiated
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        address adapter
    );

    /// @notice Emitted when a transfer status is updated
    event TransferStatusUpdated(
        bytes32 indexed transferId,
        BridgeTypes.TransferStatus status
    );

    /// @notice Emitted when a read request is initiated
    event ReadRequestInitiated(
        bytes32 indexed requestId,
        uint16 sourceChainId,
        bytes sourceContract,
        bytes4 selector,
        bytes params,
        address adapter
    );

    /// @notice Emitted when a read request status is updated
    event ReadRequestStatusUpdated(
        bytes32 indexed requestId,
        BridgeTypes.TransferStatus status
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an unknown adapter tries to perform an operation
    error UnknownAdapter();

    /// @notice Thrown when trying to register an already registered adapter
    error AdapterAlreadyRegistered();

    /// @notice Thrown when the contract is paused
    error Paused();

    /// @notice Thrown when an unauthorized address tries to perform a privileged operation
    error Unauthorized();

    /// @notice Thrown when invalid parameters are provided
    error InvalidParams();

    /// @notice Thrown when the provided fee is insufficient
    error InsufficientFee();

    /// @notice Thrown when no suitable adapter is found for a transfer
    error NoSuitableAdapter();

    /// @notice Thrown when a transfer fails
    error TransferFailed();

    /// @notice Thrown when the receiver contract rejects the cross-chain call
    error ReceiverRejectedCall();

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
            adapter = getBestAdapter(
                destinationChainId,
                asset,
                amount,
                options.bridgePreference
            );
        } else if (!adapters.contains(adapter)) {
            revert UnknownAdapter();
        }

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Transfer tokens from sender to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve the adapter to spend the tokens - first reset allowance to 0
        IERC20(asset).approve(adapter, 0);
        IERC20(asset).approve(adapter, amount);

        // Call the adapter to initiate the transfer
        transferId = IBridgeAdapter(adapter).transferAsset{value: msg.value}(
            destinationChainId,
            asset,
            recipient,
            amount,
            options.gasLimit,
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
        address adapter = getBestAdapter(
            sourceChainId,
            address(0), // No asset for read requests
            0, // No amount for read requests
            options.bridgePreference
        );

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Call the adapter's read function
        requestId = IBridgeAdapter(adapter).readState{value: msg.value}(
            sourceChainId,
            sourceContract,
            selector,
            params,
            options.gasLimit,
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
        selectedAdapter = getBestAdapter(
            destinationChainId,
            asset,
            amount,
            options.bridgePreference
        );

        if (selectedAdapter == address(0)) revert NoSuitableAdapter();

        (nativeFee, tokenFee) = IBridgeAdapter(selectedAdapter).estimateFee(
            destinationChainId,
            asset,
            amount,
            options.gasLimit,
            options.adapterParams
        );

        return (nativeFee, tokenFee, selectedAdapter);
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function updateTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
        if (transferToAdapter[transferId] != msg.sender) revert Unauthorized();

        transferStatuses[transferId] = status;
        emit TransferStatusUpdated(transferId, status);
    }

    /// @inheritdoc IBridgeRouter
    function receiveAsset(
        bytes32 transferId,
        address asset,
        address recipient,
        uint256 amount
    ) external {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
        if (transferToAdapter[transferId] != msg.sender) revert Unauthorized();

        // Update transfer status
        transferStatuses[transferId] = BridgeTypes.TransferStatus.DELIVERED;

        // Transfer the received assets to the recipient
        IERC20(asset).safeTransfer(recipient, amount);

        emit TransferStatusUpdated(
            transferId,
            BridgeTypes.TransferStatus.DELIVERED
        );
    }

    /// @inheritdoc IBridgeRouter
    function deliverReadResponse(
        bytes32 requestId,
        bytes calldata resultData
    ) external {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
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
    ) external {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
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

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeRouter
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount,
        uint8 bridgePreference
    ) public view returns (address bestAdapter) {
        if (adapters.length() == 0) return address(0);

        uint256 lowestFee = type(uint256).max;
        uint256 maxIterations = adapters.length() > 10 ? 10 : adapters.length();

        for (uint256 i = 0; i < maxIterations; i++) {
            address adapter = adapters.at(i);

            // Skip adapters that don't match our criteria
            if (
                !_isAdapterCompatible(
                    adapter,
                    chainId,
                    asset,
                    amount,
                    bridgePreference
                )
            ) {
                continue;
            }

            // For read requests, just return the first valid adapter
            if (asset == address(0) || amount == 0) {
                return adapter;
            }

            // For transfers, compare fees
            address candidate = _getAdapterWithBetterFee(
                adapter,
                chainId,
                asset,
                amount,
                lowestFee
            );
            if (candidate != address(0)) {
                bestAdapter = candidate;
                lowestFee = _getAdapterFee(adapter, chainId, asset, amount);
            }
        }

        return bestAdapter;
    }

    /**
     * @notice Checks if an adapter is compatible with the given parameters
     * @param adapter The adapter to check
     * @param chainId The destination chain ID
     * @param asset The asset to transfer (address(0) for read requests)
     * @param amount The amount to transfer (0 for read requests)
     * @param bridgePreference The preferred bridge type (0 for no preference)
     * @return True if the adapter is compatible, false otherwise
     */
    function _isAdapterCompatible(
        address adapter,
        uint16 chainId,
        address asset,
        uint256 amount,
        uint8 bridgePreference
    ) private view returns (bool) {
        // Check if adapter supports this chain
        if (!IBridgeAdapter(adapter).supportsChain(chainId)) {
            return false;
        }

        // For transfers, check if adapter supports this asset
        if (asset != address(0) && amount > 0) {
            if (!IBridgeAdapter(adapter).supportsAsset(chainId, asset)) {
                return false;
            }
        }

        // Apply bridge preference if specified
        if (bridgePreference != 0) {
            uint8 adapterType = IBridgeAdapter(adapter).getAdapterType();
            if (adapterType != bridgePreference) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Returns the adapter if it has a better fee than the current best
     * @param adapter The adapter to check
     * @param chainId The destination chain ID
     * @param asset The asset to transfer
     * @param amount The amount to transfer
     * @param currentLowestFee The current lowest fee
     * @return The adapter if it has a better fee, address(0) otherwise
     */
    function _getAdapterWithBetterFee(
        address adapter,
        uint16 chainId,
        address asset,
        uint256 amount,
        uint256 currentLowestFee
    ) private view returns (address) {
        uint256 fee = _getAdapterFee(adapter, chainId, asset, amount);

        if (fee < currentLowestFee) {
            return adapter;
        }

        return address(0);
    }

    /**
     * @notice Gets the fee for using an adapter
     * @param adapter The adapter to check
     * @param chainId The destination chain ID
     * @param asset The asset to transfer
     * @param amount The amount to transfer
     * @return The fee (or type(uint256).max if estimation fails)
     */
    function _getAdapterFee(
        address adapter,
        uint16 chainId,
        address asset,
        uint256 amount
    ) private view returns (uint256) {
        try
            IBridgeAdapter(adapter).estimateFee(
                chainId,
                asset,
                amount,
                500000, // Default gas limit
                "" // No adapter params
            )
        returns (uint256 nativeFee, uint256) {
            return nativeFee;
        } catch {
            // Return max value if estimation fails
            return type(uint256).max;
        }
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
}
