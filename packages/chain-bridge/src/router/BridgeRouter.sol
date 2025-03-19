// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers and data queries
 * @dev Implements IBridgeRouter interface and manages multiple bridge adapters
 */
contract BridgeRouter is IBridgeRouter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of adapter addresses to their registration status
    mapping(address => bool) public adapters;

    /// @notice Mapping of transfer IDs to their current status
    mapping(bytes32 => BridgeTypes.TransferStatus) public transferStatuses;

    /// @notice Mapping of transfer IDs to the adapter that processed them
    mapping(bytes32 => address) public transferToAdapter;

    /// @notice Mapping to track read request originators
    mapping(bytes32 => address) public readRequestToOriginator;

    /// @notice Address of the admin who can manage adapters and pause the system
    address public admin;

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

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the BridgeRouter contract
     * @dev Sets the deployer as the admin
     */
    constructor() {
        admin = msg.sender;
    }

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

        // Select the best adapter for this transfer
        address adapter = getBestAdapter(
            destinationChainId,
            asset,
            amount,
            options.bridgePreference
        );

        if (adapter == address(0)) revert NoSuitableAdapter();

        // Transfer tokens from sender to this contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Approve the adapter to spend the tokens
        IERC20(asset).safeApprove(adapter, amount);

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
            sourceContract,
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
        if (!adapters[msg.sender]) revert UnknownAdapter();
        if (transferToAdapter[transferId] != msg.sender) revert Unauthorized();

        transferStatuses[transferId] = status;
        emit TransferStatusUpdated(transferId, status);
    }

    /// @inheritdoc IBridgeRouter
    function deliverReadResponse(
        bytes32 requestId,
        bytes calldata resultData
    ) external {
        if (!adapters[msg.sender]) revert UnknownAdapter();
        if (transferToAdapter[requestId] != msg.sender) revert Unauthorized();

        address originator = readRequestToOriginator[requestId];
        if (originator == address(0)) revert InvalidParams();

        // Update status
        transferStatuses[requestId] = BridgeTypes.TransferStatus.DELIVERED;

        // Forward the response to the originator if it implements ICrossChainReceiver
        // This assumes ICrossChainReceiver is defined with receiveStateRead method
        try
            ICrossChainReceiver(originator).receiveStateRead(
                resultData,
                originator,
                // We need to get the sourceChainId from somewhere - could be stored when request is made
                0, // placeholder for sourceChainId
                requestId
            )
        {} catch {}

        emit ReadRequestStatusUpdated(
            requestId,
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
        uint8 preference
    ) public view returns (address bestAdapter) {
        address[] memory validAdapters = new address[](10); // Max 10 adapters
        uint256 validCount = 0;
        uint256 lowestFee = type(uint256).max;

        // Collect all valid adapters for this chain and asset
        for (uint256 i = 0; i < validAdapters.length; i++) {
            address adapter = validAdapters[i];
            if (!adapters[adapter]) continue;

            // Check if adapter supports this chain
            uint16[] memory supportedChains = IBridgeAdapter(adapter)
                .getSupportedChains();
            bool supportsChain = false;

            for (uint256 j = 0; j < supportedChains.length; j++) {
                if (supportedChains[j] == chainId) {
                    supportsChain = true;
                    break;
                }
            }

            if (!supportsChain) continue;

            // For transfers, check if adapter supports this asset
            if (asset != address(0) && amount > 0) {
                address[] memory supportedAssets = IBridgeAdapter(adapter)
                    .getSupportedAssets(chainId);
                bool supportsAsset = false;

                for (uint256 j = 0; j < supportedAssets.length; j++) {
                    if (supportedAssets[j] == asset) {
                        supportsAsset = true;
                        break;
                    }
                }

                if (!supportsAsset) continue;
            }

            // Add to valid adapters
            validAdapters[validCount] = adapter;
            validCount++;
        }

        // No valid adapters found
        if (validCount == 0) return address(0);

        // Select based on preference
        if (preference == 0) {
            // Lowest cost
            // For transfers, compare fees
            if (asset != address(0) && amount > 0) {
                for (uint256 i = 0; i < validCount; i++) {
                    address adapter = validAdapters[i];
                    (uint256 nativeFee, ) = IBridgeAdapter(adapter).estimateFee(
                        chainId,
                        asset,
                        amount,
                        500000, // Default gas limit
                        "" // No adapter params
                    );

                    if (nativeFee < lowestFee) {
                        lowestFee = nativeFee;
                        bestAdapter = adapter;
                    }
                }
            } else {
                // For reads, just select the first valid adapter
                bestAdapter = validAdapters[0];
            }
        } else if (preference == 1) {
            // Fastest
            // Implementation would depend on how we track speed
            // For now, just return the first adapter
            bestAdapter = validAdapters[0];
        } else if (preference == 2) {
            // Most secure
            // Implementation would depend on security metrics
            // For now, just return the first adapter
            bestAdapter = validAdapters[0];
        } else {
            // Default to first adapter
            bestAdapter = validAdapters[0];
        }

        return bestAdapter;
    }

    /// @inheritdoc IBridgeRouter
    function getAdapters()
        external
        view
        returns (address[] memory adapterList)
    {
        uint256 count = 0;

        // First, count the adapters
        for (uint256 i = 0; i < adapterList.length; i++) {
            if (adapters[adapterList[i]]) {
                count++;
            }
        }

        // Then populate the array
        adapterList = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < adapterList.length; i++) {
            if (adapters[adapterList[i]]) {
                adapterList[index] = adapterList[i];
                index++;
            }
        }

        return adapterList;
    }

    /// @inheritdoc IBridgeRouter
    function isValidAdapter(address adapter) external view returns (bool) {
        return adapters[adapter];
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
    function registerAdapter(address adapter) external {
        if (msg.sender != admin) revert Unauthorized();
        if (adapters[adapter]) revert AdapterAlreadyRegistered();

        adapters[adapter] = true;
        emit AdapterRegistered(adapter);
    }

    /// @inheritdoc IBridgeRouter
    function removeAdapter(address adapter) external {
        if (msg.sender != admin) revert Unauthorized();
        if (!adapters[adapter]) revert UnknownAdapter();

        adapters[adapter] = false;
        emit AdapterRemoved(adapter);
    }

    /// @inheritdoc IBridgeRouter
    function pause() external {
        if (msg.sender != admin) revert Unauthorized();
        paused = true;
    }

    /// @inheritdoc IBridgeRouter
    function unpause() external {
        if (msg.sender != admin) revert Unauthorized();
        paused = false;
    }

    /// @inheritdoc IBridgeRouter
    function setAdmin(address newAdmin) external {
        if (msg.sender != admin) revert Unauthorized();
        if (newAdmin == address(0)) revert InvalidParams();

        admin = newAdmin;
    }
}

interface ICrossChainReceiver {
    function receiveStateRead(
        bytes calldata data,
        address originator,
        uint16 sourceChainId,
        bytes32 requestId
    ) external;
}
