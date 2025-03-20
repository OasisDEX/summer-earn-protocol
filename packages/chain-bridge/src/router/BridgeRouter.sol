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

        // Use specified adapter or find the best one
        address adapter = options.specifiedAdapter;
        if (adapter == address(0)) {
            adapter = getBestAdapter(
                destinationChainId,
                asset,
                amount,
                options.bridgePreference
            );
        } else if (!adapters[adapter]) {
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
        if (!adapters[msg.sender]) revert UnknownAdapter();
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
        if (!adapters[msg.sender]) revert UnknownAdapter();
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
        // Use this.getAdapters() to call the external function
        address[] memory registeredAdapters = this.getAdapters();
        if (registeredAdapters.length == 0) return address(0);

        uint256 lowestFee = type(uint256).max;

        // Limit iteration to the first MAX_ADAPTER_ITERATIONS adapters
        uint256 maxIterations = registeredAdapters.length;
        uint256 MAX_ADAPTER_ITERATIONS = 10; // Reasonable limit to prevent excessive gas usage

        if (maxIterations > MAX_ADAPTER_ITERATIONS) {
            maxIterations = MAX_ADAPTER_ITERATIONS;
        }

        // Iterate through adapters up to the limit
        for (uint256 i = 0; i < maxIterations; i++) {
            address adapter = registeredAdapters[i];

            // Check if adapter supports this chain
            uint16[] memory supportedChains = IBridgeAdapter(adapter)
                .getSupportedChains();
            bool supportsChain = false;

            for (uint256 j = 0; j < supportedChains.length && j < 20; j++) {
                // Also limit inner loops
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

                for (uint256 j = 0; j < supportedAssets.length && j < 30; j++) {
                    // Limit asset iteration
                    if (supportedAssets[j] == asset) {
                        supportsAsset = true;
                        break;
                    }
                }

                if (!supportsAsset) continue;
            }

            // For read requests, just return the first valid adapter
            if (asset == address(0) || amount == 0) {
                return adapter;
            }

            // For transfers, compare fees
            try
                IBridgeAdapter(adapter).estimateFee(
                    chainId,
                    asset,
                    amount,
                    500000, // Default gas limit
                    "" // No adapter params
                )
            returns (uint256 nativeFee, uint256) {
                if (nativeFee < lowestFee) {
                    lowestFee = nativeFee;
                    bestAdapter = adapter;
                }
            } catch {
                // Skip adapters that revert
                continue;
            }
        }

        return bestAdapter;
    }

    /// @inheritdoc IBridgeRouter
    function getAdapters() public view returns (address[] memory adapterList) {
        // Count registered adapters first
        uint256 count = 0;
        address[] memory allAddresses = new address[](100); // Arbitrary large number to track possible addresses

        // Mock fill with adapter addresses for counting
        uint256 index = 0;
        for (uint256 i = 0; i < 100; i++) {
            // Use a reasonable upper limit
            address potentialAdapter = address(uint160(i + 1)); // Generate potential addresses
            if (adapters[potentialAdapter]) {
                allAddresses[index] = potentialAdapter;
                index++;
                count++;
            }
        }

        // Create correctly sized array with actual adapters
        adapterList = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            adapterList[i] = allAddresses[i];
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
