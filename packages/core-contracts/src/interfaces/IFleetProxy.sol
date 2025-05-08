// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";

/**
 * @title IFleetProxy
 * @author SummerFi
 * @notice Interface for the FleetProxy contract that receives and holds assets on a satellite chain
 * @dev Inherits ICrossChainReceiver to handle cross-chain messages
 */
interface IFleetProxy is ICrossChainAssetReceiver {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when assets are sent back to the source chain
     * @param token Address of the token sent
     * @param amount Amount of tokens sent
     * @param sourceChainId ID of the destination (source) chain
     * @param messageId Unique ID of the transfer message
     */
    event AssetsSent(
        address indexed token,
        uint256 amount,
        uint16 indexed sourceChainId,
        bytes32 indexed messageId
    );

    /**
     * @notice Emitted when assets are deposited into the proxy
     * @param fleetContract Address of the fleet contract
     * @param token Address of the token deposited
     * @param amount Amount of tokens deposited
     * @param sourceChainId Source chain ID
     */
    event ProxyDeposit(
        address indexed fleetContract,
        address indexed token,
        uint256 amount,
        uint16 indexed sourceChainId
    );

    /**
     * @notice Emitted when assets are withdrawn from the proxy
     * @param recipient Address of the recipient
     * @param token Address of the token withdrawn
     * @param amount Amount of tokens withdrawn
     * @param operationId Unique ID of the operation
     */
    event ProxyWithdrawal(
        address indexed recipient,
        address indexed token,
        uint256 amount,
        bytes32 indexed operationId
    );

    /**
     * @notice Emitted when a message is not expected
     */
    event MessageContentNotExpected();

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to send tokens that exceed available balance
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Thrown when the bridge operation fails
    error BridgeOperationFailed();

    /// @notice Thrown when the caller is not a registered adapter
    error CallerNotRegisteredAdapter();

    /// @notice Thrown when a function is not meant to be called directly
    error NoMessage();

    /// @notice Thrown when no assets are deposited
    error NoAssets();

    /// @notice Thrown when an invalid operation is attempted
    error InvalidOperation();

    /// @notice Thrown when an invalid asset is attempted to be deposited
    error InvalidAsset();

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current balance of a token held by this proxy
     * @param token Address of the token
     * @return Balance of the specified token
     */
    function getBalance(address token) external view returns (uint256);

    /**
     * @notice Get the total assets held by this proxy
     * @return The total balance of the main asset
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Pause the contract functionality
     * @dev Can only be called by authorized administrators
     */
    function pause() external;

    /**
     * @notice Unpause the contract functionality
     * @dev Can only be called by authorized administrators
     */
    function unpause() external;
}
