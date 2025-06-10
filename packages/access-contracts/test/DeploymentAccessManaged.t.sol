// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DeploymentAccessManaged} from "../src/contracts/DeploymentAccessManaged.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "../src/interfaces/IAccessControlErrors.sol";

// Mock contract to test the abstract DeploymentAccessManaged
contract MockDeploymentAccessManaged is DeploymentAccessManaged {
    bool public deploymentOnlyFunctionCalled;
    bool public controllerOrGovernorFunctionCalled;

    constructor(
        address initialController,
        address accessManager
    ) DeploymentAccessManaged(initialController, accessManager) {}

    function deploymentOnlyFunction() external onlyDeploymentController {
        deploymentOnlyFunctionCalled = true;
    }

    function controllerOrGovernorFunction() external onlyControllerOrGovernor {
        controllerOrGovernorFunctionCalled = true;
    }

    // Reset function for testing
    function reset() external {
        deploymentOnlyFunctionCalled = false;
        controllerOrGovernorFunctionCalled = false;
    }
}

contract DeploymentAccessManagedTest is Test {
    MockDeploymentAccessManaged public deploymentAccessManaged;
    ProtocolAccessManager public accessManager;

    address public deployer = address(0x1);
    address public governance = address(0x2);
    address public randomUser = address(0x3);

    event ControllerUpdated(
        address indexed oldController,
        address indexed newController
    );
    event GovernanceModeActivated(address indexed governance);

    function setUp() public {
        // Create access manager with governance
        vm.prank(governance);
        accessManager = new ProtocolAccessManager(governance);

        // Deploy the mock contract with deployer as initial controller
        vm.prank(deployer);
        deploymentAccessManaged = new MockDeploymentAccessManaged(
            deployer,
            address(accessManager)
        );
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_Success() public {
        assertEq(deploymentAccessManaged.controller(), deployer);
        assertTrue(deploymentAccessManaged.isInDeploymentPhase());
        assertFalse(deploymentAccessManaged.isGovernanceModeActive());
    }

    function test_Constructor_EmitsControllerUpdated() public {
        vm.expectEmit(true, true, true, true);
        emit ControllerUpdated(address(0), deployer);

        vm.prank(deployer);
        new MockDeploymentAccessManaged(deployer, address(accessManager));
    }

    function test_Constructor_RevertsOnZeroController() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged.InvalidController.selector,
                address(0)
            )
        );

        vm.prank(deployer);
        new MockDeploymentAccessManaged(address(0), address(accessManager));
    }

    /*//////////////////////////////////////////////////////////////
                     DEPLOYMENT PHASE MODIFIER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OnlyDeploymentController_Success() public {
        vm.prank(deployer);
        deploymentAccessManaged.deploymentOnlyFunction();
        assertTrue(deploymentAccessManaged.deploymentOnlyFunctionCalled());
    }

    function test_OnlyDeploymentController_RevertsForNonController() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                randomUser
            )
        );

        vm.prank(randomUser);
        deploymentAccessManaged.deploymentOnlyFunction();
    }

    function test_OnlyDeploymentController_RevertsForGovernance() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                governance
            )
        );

        vm.prank(governance);
        deploymentAccessManaged.deploymentOnlyFunction();
    }

    function test_OnlyDeploymentController_RevertsAfterGovernanceTransition()
        public
    {
        // First transition to governance
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Now deployer should not be able to call deployment-only functions
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                deployer
            )
        );

        vm.prank(deployer);
        deploymentAccessManaged.deploymentOnlyFunction();
    }

    /*//////////////////////////////////////////////////////////////
                  CONTROLLER OR GOVERNOR MODIFIER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OnlyControllerOrGovernor_DeploymentPhase_Controller() public {
        vm.prank(deployer);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );
    }

    function test_OnlyControllerOrGovernor_DeploymentPhase_RevertsForGovernance()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                governance
            )
        );

        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();
    }

    function test_OnlyControllerOrGovernor_DeploymentPhase_RevertsForRandomUser()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                randomUser
            )
        );

        vm.prank(randomUser);
        deploymentAccessManaged.controllerOrGovernorFunction();
    }

    function test_OnlyControllerOrGovernor_GovernancePhase_Governor() public {
        // Transition to governance
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Reset state
        deploymentAccessManaged.reset();

        // Governance should be able to call
        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );
    }

    function test_OnlyControllerOrGovernor_GovernancePhase_RevertsForOldController()
        public
    {
        // Transition to governance
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Old controller should not be able to call
        vm.expectRevert();

        vm.prank(deployer);
        deploymentAccessManaged.controllerOrGovernorFunction();
    }

    function test_OnlyControllerOrGovernor_GovernancePhase_RevertsForRandomUser()
        public
    {
        // Transition to governance
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        vm.expectRevert();

        vm.prank(randomUser);
        deploymentAccessManaged.controllerOrGovernorFunction();
    }

    /*//////////////////////////////////////////////////////////////
                     TRANSFER TO GOVERNANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TransferToGovernance_Success() public {
        vm.expectEmit(true, true, true, true);
        emit ControllerUpdated(deployer, governance);

        vm.expectEmit(true, true, true, true);
        emit GovernanceModeActivated(governance);

        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        assertEq(deploymentAccessManaged.controller(), governance);
        assertFalse(deploymentAccessManaged.isInDeploymentPhase());
        assertTrue(deploymentAccessManaged.isGovernanceModeActive());
    }

    function test_TransferToGovernance_RevertsForNonController() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                randomUser
            )
        );

        vm.prank(randomUser);
        deploymentAccessManaged.transferToGovernance(governance);
    }

    function test_TransferToGovernance_RevertsForZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged.InvalidController.selector,
                address(0)
            )
        );

        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(address(0));
    }

    function test_TransferToGovernance_RevertsForNonGovernor() public {
        vm.expectRevert();

        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(randomUser);
    }

    function test_TransferToGovernance_RevertsAfterAlreadyTransitioned()
        public
    {
        // First transition
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Try to transition again - should revert because deployer is no longer controller
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                deployer
            )
        );

        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_IsInDeploymentPhase_InitiallyTrue() public {
        assertTrue(deploymentAccessManaged.isInDeploymentPhase());
    }

    function test_IsInDeploymentPhase_FalseAfterTransition() public {
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        assertFalse(deploymentAccessManaged.isInDeploymentPhase());
    }

    function test_IsGovernanceModeActive_InitiallyFalse() public {
        assertFalse(deploymentAccessManaged.isGovernanceModeActive());
    }

    function test_IsGovernanceModeActive_TrueAfterTransition() public {
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        assertTrue(deploymentAccessManaged.isGovernanceModeActive());
    }

    /*//////////////////////////////////////////////////////////////
                           INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullWorkflow_DeploymentToGovernance() public {
        // Initial state - deployment phase
        assertTrue(deploymentAccessManaged.isInDeploymentPhase());
        assertFalse(deploymentAccessManaged.isGovernanceModeActive());
        assertEq(deploymentAccessManaged.controller(), deployer);

        // Deployer can call both types of functions
        vm.startPrank(deployer);
        deploymentAccessManaged.deploymentOnlyFunction();
        assertTrue(deploymentAccessManaged.deploymentOnlyFunctionCalled());

        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );
        vm.stopPrank();

        // Reset state
        deploymentAccessManaged.reset();

        // Governance cannot call functions during deployment phase
        vm.expectRevert();
        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();

        // Transition to governance
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Post-transition state
        assertFalse(deploymentAccessManaged.isInDeploymentPhase());
        assertTrue(deploymentAccessManaged.isGovernanceModeActive());
        assertEq(deploymentAccessManaged.controller(), governance);

        // Deployer can no longer call any functions
        vm.expectRevert();
        vm.prank(deployer);
        deploymentAccessManaged.deploymentOnlyFunction();

        vm.expectRevert();
        vm.prank(deployer);
        deploymentAccessManaged.controllerOrGovernorFunction();

        // Governance can call controllerOrGovernor functions but not deployment-only
        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );

        vm.expectRevert();
        vm.prank(governance);
        deploymentAccessManaged.deploymentOnlyFunction();
    }

    function test_MultipleGovernors() public {
        address governor2 = address(0x4);

        // Grant governor role to second address using proper method
        vm.prank(governance);
        accessManager.grantGovernorRole(governor2);

        // Transition to governance using first governor
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Both governors should be able to call controllerOrGovernor functions
        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );

        deploymentAccessManaged.reset();

        vm.prank(governor2);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );
    }

    /*//////////////////////////////////////////////////////////////
                              EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_ControllerIsGovernorFromStart() public {
        // Create a scenario where the controller is already a governor
        vm.prank(governance);
        accessManager.grantGovernorRole(deployer);

        // Contract should NOT be in deployment phase if controller is already a governor
        assertFalse(deploymentAccessManaged.isInDeploymentPhase());
        assertTrue(deploymentAccessManaged.isGovernanceModeActive());

        // transferToGovernance should not be callable since we're already in governance mode
        vm.expectRevert(
            abi.encodeWithSelector(
                DeploymentAccessManaged
                    .CallerIsNotDeploymentController
                    .selector,
                deployer
            )
        );
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(deployer);

        // Should still be in governance mode
        assertFalse(deploymentAccessManaged.isInDeploymentPhase());
        assertTrue(deploymentAccessManaged.isGovernanceModeActive());
    }

    function test_AccessManagerRoleRevocation() public {
        // Transition to governance
        vm.prank(deployer);
        deploymentAccessManaged.transferToGovernance(governance);

        // Governance should work initially
        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );

        // Reset state
        deploymentAccessManaged.reset();

        // Revoke governor role using proper method
        vm.prank(governance);
        accessManager.revokeGovernorRole(governance);

        // Debug: Check what happens after role revocation
        // Governance no longer has governor role
        assertFalse(
            accessManager.hasRole(accessManager.GOVERNOR_ROLE(), governance)
        );

        // Contract thinks it's back in deployment phase (design flaw!)
        assertTrue(deploymentAccessManaged.isInDeploymentPhase());
        assertFalse(deploymentAccessManaged.isGovernanceModeActive());

        // Governance can still call the function because it's now treated as deployment controller
        vm.prank(governance);
        deploymentAccessManaged.controllerOrGovernorFunction();
        assertTrue(
            deploymentAccessManaged.controllerOrGovernorFunctionCalled()
        );
    }
}
