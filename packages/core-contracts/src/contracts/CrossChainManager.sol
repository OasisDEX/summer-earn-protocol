// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ConfigurationManaged} from "@summerfi/config-contracts/contracts/ConfigurationManaged.sol";

import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {ValidatedCallerBase} from "./intent/ValidatedCallerBase.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title CrossChainManager
 * @notice Receives tokens (e.g. via bridging) and deposits them into a validated FleetCommander (ERC4626).
 * @dev Uses HarborCommand to validate FleetCommander addresses, and shares the same
 *      validated arbitrary call mechanism as `CrossChainArk` via `ValidatedCallerBase`.
 */
contract CrossChainManager is
    ReentrancyGuardTransient,
    ConfigurationManaged,
    ValidatedCallerBase,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _configurationManager Address of the configuration manager
     * @param _validationRegistry Address of the call validation registry
     */
    constructor(
        address _configurationManager,
        address _validationRegistry,
        address _accessManager
    )
        ConfigurationManaged(_configurationManager)
        ValidatedCallerBase(_validationRegistry)
        ProtocolAccessManaged(_accessManager)
    {}

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits tokens held by this contract into a FleetCommander.
     * @dev Validates the FleetCommander via HarborCommand configuration.
     * @param fleetCommander The FleetCommander (ERC4626) to deposit into
     * @param assets Amount of assets to deposit; if 0, uses full local balance
     * @param receiver Receiver of FleetCommander shares; if 0, uses msg.sender
     * @return shares Amount of shares minted by the FleetCommander
     */
    function depositIntoFleet(
        address fleetCommander,
        uint256 assets,
        address receiver
    ) external nonReentrant onlySuperKeeper returns (uint256 shares) {
        _validateFleetCommander(fleetCommander);

        IFleetCommander fleet = IFleetCommander(fleetCommander);
        IERC20 fleetAsset = IERC20(fleet.asset());

        uint256 balance = fleetAsset.balanceOf(address(this));
        assets = assets == 0 ? balance : assets;
        if (assets > balance) {
            revert InsufficientAssets();
        }

        receiver = receiver == address(0) ? msg.sender : receiver;

        fleetAsset.forceApprove(fleetCommander, assets);
        shares = fleet.deposit(assets, receiver, "");

        emit FleetDeposited(fleetCommander, receiver, assets, shares);
    }

    /**
     * @notice Execute an arbitrary call from the manager after registry validation.
     * @dev Intended for interacting with bridging/middleware or recovery flows.
     * @param target The target address to call
     * @param data The calldata for the call
     * @return result The raw returned data from the call
     */
    function executeCall(
        address target,
        bytes calldata data
    ) external nonReentrant onlySuperKeeper returns (bytes memory result) {
        // Access control for this method can be further restricted via the registry logic.
        return _executeValidatedCall(target, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _validateFleetCommander(address fleetCommander) internal view {
        if (
            !IHarborCommand(harborCommand()).activeFleetCommanders(
                fleetCommander
            )
        ) {
            revert InvalidFleetCommander();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when assets are deposited into a FleetCommander
    event FleetDeposited(
        address indexed fleetCommander,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when not enough assets are held locally to satisfy a deposit
    error InsufficientAssets();
    /// @notice Thrown when HarborCommand does not recognise the FleetCommander as active
    error InvalidFleetCommander();
}
