// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IFleetDepositAdapter} from "@summerfi/chain-bridge/interfaces/IFleetDepositAdapter.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";

/**
 * @title FleetDepositManager
 * @notice Vendor-agnostic contract for managing cross-chain fleet deposits
 * @dev Orchestrates fleet deposits through any bridge adapter registered with BridgeRouter
 *      Users can choose their preferred bridge technology (Stargate, LayerZero, Hyperlane, etc.)
 */
contract FleetDepositManager is ReentrancyGuard, ProtocolAccessManaged {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a fleet deposit to target chain is initiated
    event FleetDepositToTargetChainInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed user,
        address bridgeAdapter,
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient
    );

    /// @notice Emitted when the bridge router address is updated
    event BridgeRouterUpdated(
        address indexed oldRouter,
        address indexed newRouter
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when invalid parameters are provided
    error InvalidParams();

    /// @notice Thrown when bridge adapter is not supported
    error UnsupportedBridgeAdapter();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeRouter that manages bridge adapters
    IBridgeRouter public bridgeRouter;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the FleetDepositManager
     * @param _bridgeRouter Address of the BridgeRouter
     * @param _accessManager Address of the ProtocolAccessManager
     */
    constructor(
        address _bridgeRouter,
        address _accessManager
    ) ProtocolAccessManaged(_accessManager) {
        if (_bridgeRouter == address(0)) revert InvalidParams();
        bridgeRouter = IBridgeRouter(_bridgeRouter);
    }

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the bridge router address
     * @param _newBridgeRouter Address of the new BridgeRouter
     * @dev Only callable by governance
     */
    function setBridgeRouter(address _newBridgeRouter) external onlyGovernor {
        if (_newBridgeRouter == address(0)) revert InvalidParams();

        address oldRouter = address(bridgeRouter);
        bridgeRouter = IBridgeRouter(_newBridgeRouter);

        emit BridgeRouterUpdated(oldRouter, _newBridgeRouter);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a deposit to a fleet on a target chain using the specified bridge adapter
     * @param bridgeAdapter Address of the bridge adapter to use (user's choice)
     * @param destinationChainId Target chain ID where the FleetCommander is deployed
     * @param asset Asset to bridge and deposit
     * @param amount Amount to bridge and deposit
     * @param fleetCommander FleetCommander address on destination chain
     * @param shareRecipient Address to receive the FleetCommander shares
     * @param referralCode Optional referral code for tracking
     * @param adapterParams Bridge-specific adapter parameters
     * @return operationId Unique identifier for this cross-chain deposit operation
     */
    function initiateDepositToTargetChainFleet(
        address bridgeAdapter,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address fleetCommander,
        address shareRecipient,
        bytes memory referralCode,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable nonReentrant returns (bytes32 operationId) {
        // Validate inputs
        if (amount == 0) revert InvalidParams();
        if (fleetCommander == address(0)) revert InvalidParams();
        if (shareRecipient == address(0)) revert InvalidParams();

        // Check if adapter is registered with BridgeRouter
        if (!_isAdapterSupported(bridgeAdapter)) {
            revert UnsupportedBridgeAdapter();
        }

        // Create fleet deposit compose message
        bytes memory composeMessage = encodeFleetDepositMessage(
            fleetCommander,
            shareRecipient,
            asset,
            amount,
            referralCode
        );

        // Transfer tokens from user to this contract, then approve adapter
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(asset).forceApprove(bridgeAdapter, amount);

        // Execute cross-chain deposit through the chosen adapter using standard interface
        operationId = IFleetDepositAdapter(bridgeAdapter)
            .sendFleetDepositToDestinationChain{value: msg.value}(
            destinationChainId,
            asset,
            amount,
            address(0), // destinationAdapter - not needed, adapter handles this
            composeMessage,
            adapterParams
        );

        emit FleetDepositToTargetChainInitiated(
            operationId,
            destinationChainId,
            msg.sender,
            bridgeAdapter,
            fleetCommander,
            asset,
            amount,
            shareRecipient
        );
    }

    /**
     * @notice Encodes a fleet deposit compose message for fee estimation
     * @param fleetCommander FleetCommander address on destination chain
     * @param shareRecipient Share recipient address
     * @param asset Asset to bridge
     * @param amount Amount to bridge
     * @param referralCode Referral code
     * @return composeMessage Encoded compose message for use with adapter's estimateFee
     */
    function encodeFleetDepositMessage(
        address fleetCommander,
        address shareRecipient,
        address asset,
        uint256 amount,
        bytes memory referralCode
    ) public view returns (bytes memory composeMessage) {
        // Create the struct and encode it directly
        BridgeTypes.FleetDepositMessageData memory messageData = BridgeTypes
            .FleetDepositMessageData({
                fleetCommander: fleetCommander,
                shareRecipient: shareRecipient,
                asset: asset,
                amount: amount,
                sourceChainId: block.chainid,
                operationId: bytes32(0), // Operation ID placeholder
                originalUser: msg.sender, // Original user
                referralCode: referralCode
            });

        return abi.encode(BridgeTypes.FLEET_DEPOSIT_TYPE, messageData);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a bridge adapter is supported by the BridgeRouter
     * @param adapter Address of the adapter to check
     * @return True if the adapter is supported
     */
    function isAdapterSupported(address adapter) external view returns (bool) {
        return _isAdapterSupported(adapter);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to check if adapter is supported by BridgeRouter
     */
    function _isAdapterSupported(address adapter) internal view returns (bool) {
        return
            bridgeRouter.isValidAdapter(adapter) &&
            IFleetDepositAdapter(adapter).supportsUserInitiatedFleetDeposits();
    }
}
