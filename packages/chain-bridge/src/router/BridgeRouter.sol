// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title BridgeRouter
 * @notice Central router that coordinates cross-chain asset transfers
 */
contract BridgeRouter is IBridgeRouter {
    // State variables
    mapping(address => bool) public adapters;
    mapping(bytes32 => BridgeTypes.TransferStatus) public transferStatuses;
    address public admin;
    bool public paused;

    // Events
    event AdapterRegistered(address indexed adapter);
    event AdapterRemoved(address indexed adapter);
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount
    );
    event TransferStatusUpdated(
        bytes32 indexed transferId,
        BridgeTypes.TransferStatus status
    );

    // Errors
    error UnknownAdapter();
    error AdapterAlreadyRegistered();
    error Paused();
    error Unauthorized();
    error InvalidParams();
    error InsufficientFee();

    // Constructor and functions to be implemented
}
