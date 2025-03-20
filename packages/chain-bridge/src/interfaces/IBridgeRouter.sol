// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IBridgeRouter
 * @notice Interface for the BridgeRouter contract that coordinates cross-chain asset transfers
 * @dev This interface defines all external functions for interacting with bridge adapters
 */
interface IBridgeRouter {
    /*//////////////////////////////////////////////////////////////
                        USER BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer an asset to a destination chain
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param recipient Address of the recipient on the destination chain
     * @param options Additional options for the transfer
     * @return transferId Unique ID to track this transfer
     * @dev This function selects the best adapter for the transfer based on user preferences,
     *      transfers tokens from sender to the router, and initiates the cross-chain transfer
     */
    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 transferId);

    /**
     * @notice Read data from another chain (async operation)
     * @param sourceChainId ID of the source chain
     * @param sourceContract Address of the contract on the source chain
     * @param selector Function selector to call
     * @param params Parameters for the function call
     * @param options Additional options for the read operation
     * @return requestId Unique ID to track this read request
     * @dev This function initiates a cross-chain read operation that will be completed
     *      asynchronously when the response is received from the source chain
     */
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Estimate the fee required for a cross-chain transfer
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param options Additional options for the transfer
     * @return nativeFee Fee in native token
     * @return tokenFee Fee in the asset token
     * @return selectedAdapter Address of the selected adapter
     * @dev This function provides a quote for the fees needed to complete a transfer
     *      without actually initiating the transfer
     */
    function quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter);

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receive and deliver read responses from adapters
     * @param requestId Unique identifier for the read request
     * @param resultData The data returned from the source chain
     * @dev This function is called by bridge adapters when a read request has been completed
     *      It forwards the result to the original requester
     */
    function deliverReadResponse(
        bytes32 requestId,
        bytes calldata resultData
    ) external;

    /**
     * @notice Update the status of a transfer (called by adapters)
     * @param transferId ID of the transfer to update
     * @param status New status of the transfer
     * @dev This function can only be called by the adapter that initiated the transfer
     */
    function updateTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external;

    /**
     * @notice Called by a bridge adapter when assets are received from another chain
     * @param transferId ID of the transfer
     * @param asset Address of the asset received
     * @param recipient Address to receive the assets
     * @param amount Amount of assets received
     */
    function receiveAsset(
        bytes32 transferId,
        address asset,
        address recipient,
        uint256 amount
    ) external;

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the status of a transfer
     * @param transferId ID of the transfer
     * @return Status of the transfer
     * @dev Returns the current status of a cross-chain transfer or read operation
     */
    function getTransferStatus(
        bytes32 transferId
    ) external view returns (BridgeTypes.TransferStatus);

    /**
     * @notice Get the best adapter for a specific transfer
     * @param chainId ID of the destination/source chain
     * @param asset Address of the asset (address(0) for native/reads)
     * @param amount Amount to transfer (0 for reads)
     * @param preference Preference for selecting adapter (0=lowest cost, 1=fastest, 2=most secure)
     * @return bestAdapter Address of the best adapter
     * @dev Determines the most suitable adapter based on the transfer parameters and user preferences.
     *      When preference is 0, selects adapter with lowest fee.
     *      When preference is non-zero, filters adapters by their type (1=fastest, 2=most secure).
     *      For read operations (asset=address(0) or amount=0), returns first valid adapter.
     */
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount,
        uint8 preference
    ) external view returns (address bestAdapter);

    /**
     * @notice Get all registered adapters
     * @return adapterList Array of registered adapter addresses
     * @dev Returns a list of all currently registered bridge adapters
     */
    function getAdapters() external view returns (address[] memory adapterList);

    /**
     * @notice Check if an address is a registered adapter
     * @param adapter Address to check
     * @return isValid True if the address is a registered adapter
     * @dev Verifies whether the given address is a registered bridge adapter
     */
    function isValidAdapter(address adapter) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new bridge adapter
     * @param adapter Address of the adapter to register
     * @dev Only callable by the admin
     */
    function registerAdapter(address adapter) external;

    /**
     * @notice Remove a bridge adapter
     * @param adapter Address of the adapter to remove
     * @dev Only callable by the admin
     */
    function removeAdapter(address adapter) external;

    /**
     * @notice Pause all bridge operations
     * @dev Only callable by the admin
     */
    function pause() external;

    /**
     * @notice Unpause bridge operations
     * @dev Only callable by the admin
     */
    function unpause() external;
}
