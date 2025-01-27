// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/contracts/ProtocolAccessManaged.sol";
import "../src/contracts/ProtocolAccessManager.sol";

contract MockProtocolAccessManaged is ProtocolAccessManaged {
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {}

    function testOnlyGovernor() external onlyGovernor {}

    function testOnlyKeeper() external onlyKeeper {}

    function testOnlySuperKeeper() external onlySuperKeeper {}

    function testOnlyCurator(address fleet) external onlyCurator(fleet) {}

    function testOnlyGuardian() external onlyGuardian {}

    function testOnlyGuardianOrGovernor() external onlyGuardianOrGovernor {}

    function testOnlyDecayController() external onlyDecayController {}

    function testOnlyFoundation() external onlyFoundation {}
}

contract ProtocolAccessManagedTest is Test {
    ProtocolAccessManager public accessManager;
    MockProtocolAccessManaged public managed;

    address public governor = address(1);
    address public keeper = address(2);
    address public superKeeper = address(3);
    address public curator = address(4);
    address public guardian = address(5);
    address public decayController = address(6);
    address public foundation = address(7);
    address public mockFleet = address(8);
    address public admin = address(9);

    function setUp() public {
        // Deploy access manager with admin
        accessManager = new ProtocolAccessManager(admin);

        // Deploy mock managed contract
        managed = new MockProtocolAccessManaged(address(accessManager));

        // Setup roles using the proper grant functions
        vm.startPrank(admin);
        accessManager.grantGovernorRole(governor);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(managed),
            keeper
        );
        accessManager.grantSuperKeeperRole(superKeeper);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.CURATOR_ROLE,
            mockFleet,
            curator
        );
        accessManager.grantGuardianRole(guardian);
        accessManager.grantDecayControllerRole(decayController);
        accessManager.grantFoundationRole(foundation);
        vm.stopPrank();
    }

    function test_Constructor_ZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.InvalidAccessManagerAddress.selector,
                address(0)
            )
        );
        new MockProtocolAccessManaged(address(0));
    }

    function test_OnlyGovernor() public {
        vm.prank(governor);
        managed.testOnlyGovernor();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                address(this)
            )
        );
        managed.testOnlyGovernor();
    }

    function test_OnlyKeeper() public {
        vm.prank(keeper);
        managed.testOnlyKeeper();

        vm.prank(superKeeper);
        managed.testOnlyKeeper();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotKeeper.selector,
                address(this)
            )
        );
        managed.testOnlyKeeper();
    }

    function test_OnlySuperKeeper() public {
        vm.prank(superKeeper);
        managed.testOnlySuperKeeper();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotSuperKeeper.selector,
                address(this)
            )
        );
        managed.testOnlySuperKeeper();
    }

    function test_OnlyCurator() public {
        vm.prank(curator);
        managed.testOnlyCurator(mockFleet);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotCurator.selector,
                address(this)
            )
        );
        managed.testOnlyCurator(mockFleet);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotCurator.selector,
                address(this)
            )
        );
        managed.testOnlyCurator(address(0));
    }

    function test_OnlyGuardian() public {
        vm.prank(guardian);
        managed.testOnlyGuardian();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGuardian.selector,
                address(this)
            )
        );
        managed.testOnlyGuardian();
    }

    function test_OnlyGuardianOrGovernor() public {
        vm.prank(guardian);
        managed.testOnlyGuardianOrGovernor();

        vm.prank(governor);
        managed.testOnlyGuardianOrGovernor();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGuardianOrGovernor.selector,
                address(this)
            )
        );
        managed.testOnlyGuardianOrGovernor();
    }

    function test_OnlyDecayController() public {
        vm.prank(decayController);
        managed.testOnlyDecayController();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotDecayController.selector,
                address(this)
            )
        );
        managed.testOnlyDecayController();
    }

    function test_OnlyFoundation() public {
        vm.prank(foundation);
        managed.testOnlyFoundation();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotFoundation.selector,
                address(this)
            )
        );
        managed.testOnlyFoundation();
    }

    function test_GenerateRole() public {
        bytes32 expectedRole = keccak256(
            abi.encodePacked(
                ContractSpecificRoles.KEEPER_ROLE,
                address(managed)
            )
        );
        assertEq(
            managed.generateRole(
                ContractSpecificRoles.KEEPER_ROLE,
                address(managed)
            ),
            expectedRole
        );
    }

    function test_HasAdmiralsQuartersRole() public {
        address testAccount = address(10);
        assertFalse(managed.hasAdmiralsQuartersRole(testAccount));

        vm.prank(admin);
        accessManager.grantAdmiralsQuartersRole(testAccount);

        assertTrue(managed.hasAdmiralsQuartersRole(testAccount));
    }
}
