// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title DeploymentAccessManaged
 * @notice Standardized access control with one-way deployment-to-governance transition
 * @dev Inherits ProtocolAccessManaged and provides controller pattern during deployment,
 *      then permanently transitions to governance-based access control
 */
abstract contract DeploymentAccessManaged is ProtocolAccessManaged {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Current controller address (starts as deployer, transitions to governance)
    address public controller;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when controller is updated
    event ControllerUpdated(
        address indexed oldController,
        address indexed newController
    );

    /// @notice Emitted when governance mode is permanently activated
    event GovernanceModeActivated(address indexed governance);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when caller is not the deployment controller
    error CallerIsNotDeploymentController(address caller);

    /// @notice Thrown when invalid controller address is provided
    error InvalidController(address controller);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the controller and access manager
     * @param initialController Address of the initial controller (deployer)
     * @param accessManager Address of the ProtocolAccessManager
     */
    constructor(
        address initialController,
        address accessManager
    ) ProtocolAccessManaged(accessManager) {
        if (initialController == address(0))
            revert InvalidController(initialController);

        controller = initialController;
        emit ControllerUpdated(address(0), initialController);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier for deployment-phase configuration (deployer only)
     * @dev Only usable during deployment phase before governance transition
     */
    modifier onlyDeploymentController() {
        if (!_isInDeploymentPhase()) {
            revert CallerIsNotDeploymentController(msg.sender);
        }
        if (msg.sender != controller) {
            revert CallerIsNotDeploymentController(msg.sender);
        }
        _;
    }

    /**
     * @notice Modifier for configuration that can be done by either deployer or governance
     * @dev During deployment: only controller can call
     *      After governance transition: only governors can call
     */
    modifier onlyControllerOrGovernor() {
        if (_isInDeploymentPhase()) {
            // Deployment phase: only controller
            if (msg.sender != controller) {
                revert CallerIsNotDeploymentController(msg.sender);
            }
        } else {
            // Governance phase: only governors
            if (!_isGovernor(msg.sender)) {
                revert CallerIsNotGovernor(msg.sender);
            }
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        CONTROLLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Permanently transfers control to governance
     * @param governance Address of the governance contract/multisig
     * @dev Can only be called once during deployment phase by current controller
     *      After this call, all future configuration must go through normal governance
     *
     *      The governance address must be explicitly specified because:
     *      - Multiple addresses can have GOVERNOR_ROLE
     *      - AccessControl doesn't provide role enumeration
     *      - Explicit specification prevents accidents and improves auditability
     *
     *      To find the governance address, check your ProtocolAccessManager deployment
     *      or governance documentation.
     */
    function transferToGovernance(
        address governance
    ) external onlyDeploymentController {
        if (governance == address(0)) revert InvalidController(governance);

        // Verify the new controller is actually a governor in the access manager
        if (!_isGovernor(governance)) {
            revert CallerIsNotGovernor(governance);
        }

        address oldController = controller;
        controller = governance;

        emit ControllerUpdated(oldController, governance);
        emit GovernanceModeActivated(governance);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if contract is still in deployment phase
     * @return True if controller is not a governor in the access manager
     */
    function isInDeploymentPhase() external view returns (bool) {
        return _isInDeploymentPhase();
    }

    /**
     * @notice Check if governance mode is active
     * @return True if controller is a governor in the access manager
     */
    function isGovernanceModeActive() external view returns (bool) {
        return !_isInDeploymentPhase();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to check if in deployment phase
     * @return True if controller is not a governor in the access manager
     */
    function _isInDeploymentPhase() internal view returns (bool) {
        return !_isGovernor(controller);
    }
}
