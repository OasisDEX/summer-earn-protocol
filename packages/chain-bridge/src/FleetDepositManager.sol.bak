// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IFleetDepositAdapter} from "./interfaces/IFleetDepositAdapter.sol";
import {IBridgeRouter} from "./interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "./libraries/BridgeTypes.sol";

/**
 * @title FleetDepositManager
 * @notice Vendor-agnostic contract for managing cross-chain fleet deposits
 * @dev Orchestrates fleet deposits through any bridge adapter registered with BridgeRouter
 *      Users can choose their preferred bridge technology (Stargate, LayerZero, Hyperlane, etc.)
 */
contract FleetDepositManager is ProtocolAccessManaged, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a cross-chain fleet deposit is initiated
    event CrossChainFleetDepositInitiated(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed user,
        address bridgeAdapter,
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient
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
    IBridgeRouter public immutable bridgeRouter;

    /// @notice Fleet deposit message type identifier
    bytes32 public constant FLEET_DEPOSIT_TYPE = keccak256("FLEET_DEPOSIT");

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the FleetDepositManager
     * @param accessManager Address of the ProtocolAccessManager
     * @param _bridgeRouter Address of the BridgeRouter
     */
    constructor(
        address accessManager,
        address _bridgeRouter
    ) ProtocolAccessManaged(accessManager) {
        if (_bridgeRouter == address(0)) revert InvalidParams();
        bridgeRouter = IBridgeRouter(_bridgeRouter);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a cross-chain fleet deposit using the specified bridge adapter
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
    function crossChainDepositToFleet(
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
        bytes memory composeMessage = abi.encode(
            FLEET_DEPOSIT_TYPE, // Message type identifier
            fleetCommander, // FleetCommander address
            shareRecipient, // Share recipient
            asset, // Asset being deposited
            amount, // Amount to deposit
            block.chainid, // Source chain ID
            bytes32(0), // Operation ID (will be set by adapter)
            msg.sender, // Original user
            referralCode // Referral code
        );

        // Transfer tokens from user to bridge adapter
        IERC20(asset).safeTransferFrom(msg.sender, bridgeAdapter, amount);

        // Create updated adapter params with compose message
        BridgeTypes.AdapterParams memory updatedParams = BridgeTypes
            .AdapterParams({
                gasLimit: adapterParams.gasLimit,
                calldataSize: adapterParams.calldataSize,
                msgValue: adapterParams.msgValue,
                options: composeMessage // Pass compose message as options
            });

        // Execute cross-chain deposit through the chosen adapter using standard interface
        operationId = IFleetDepositAdapter(bridgeAdapter)
            .executeCrossChainFleetDeposit{value: msg.value}(
            destinationChainId,
            asset,
            amount,
            address(0), // destinationAdapter - not needed, adapter handles this
            composeMessage,
            updatedParams
        );

        emit CrossChainFleetDepositInitiated(
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
     * @notice Creates a fleet deposit compose message for fee estimation
     * @param fleetCommander FleetCommander address on destination chain
     * @param shareRecipient Share recipient address
     * @param asset Asset to bridge
     * @param amount Amount to bridge
     * @param referralCode Referral code
     * @return composeMessage Encoded compose message for use with adapter's estimateFee
     */
    function createFleetDepositMessage(
        address fleetCommander,
        address shareRecipient,
        address asset,
        uint256 amount,
        bytes memory referralCode
    ) external view returns (bytes memory composeMessage) {
        return
            abi.encode(
                FLEET_DEPOSIT_TYPE,
                fleetCommander,
                shareRecipient,
                asset,
                amount,
                block.chainid,
                bytes32(0), // Operation ID placeholder
                msg.sender, // Original user
                referralCode
            );
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
        // Check if adapter supports fleet deposits and is registered with BridgeRouter
        try IFleetDepositAdapter(adapter).supportsFleetDeposits() returns (
            bool supports
        ) {
            return supports && bridgeRouter.isValidAdapter(adapter);
        } catch {
            return false;
        }
    }
}
