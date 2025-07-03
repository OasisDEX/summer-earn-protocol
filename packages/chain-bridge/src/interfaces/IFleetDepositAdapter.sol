// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IFleetDepositAdapter
 * @notice Interface for bridge adapters that support cross-chain fleet deposits
 * @dev This interface allows any bridge technology (Stargate, LayerZero, Hyperlane, etc.)
 *      to be used for cross-chain fleet deposits in a vendor-agnostic way
 */
interface IFleetDepositAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a fleet deposit is sent to destination chain through this adapter
    event FleetDepositSentToDestination(
        bytes32 indexed operationId,
        uint16 indexed destinationChainId,
        address indexed user,
        address fleetCommander,
        address asset,
        uint256 amount,
        address shareRecipient,
        address adapter
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the adapter doesn't support user-initiated fleet deposits
    error UserInitiatedFleetDepositsNotSupported();

    /// @notice Thrown when fleet deposit parameters are invalid
    error InvalidFleetDepositParams();

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sends a fleet deposit to a destination chain using this bridge adapter
     * @param destinationChainId Target chain ID where the FleetCommander is deployed
     * @param asset Asset to bridge and deposit
     * @param amount Amount to bridge and deposit
     * @param destinationAdapter Address of the corresponding adapter on destination chain
     * @param composeMessage Encoded message containing fleet deposit instructions
     * @param adapterParams Bridge-specific adapter parameters
     * @return operationId Unique identifier for this cross-chain deposit operation
     * @dev The adapter should:
     *      1. Transfer tokens from caller to itself
     *      2. Execute the cross-chain transfer with compose message
     *      3. Return a unique operation ID for tracking
     */
    function sendFleetDepositToDestinationChain(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address destinationAdapter,
        bytes memory composeMessage,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 operationId);

    /*//////////////////////////////////////////////////////////////
                          CAPABILITY CHECKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if this adapter supports user-initiated fleet deposits
     * @dev This is distinct from keeper-led deposits via fleet proxies
     * @return True if user-initiated fleet deposits are supported
     */
    function supportsUserInitiatedFleetDeposits() external view returns (bool);
}
