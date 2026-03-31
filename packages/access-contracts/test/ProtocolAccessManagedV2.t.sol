// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { ProtocolAccessManagedV2 } from "../src/contracts/ProtocolAccessManagedV2.sol";
import { ProtocolAccessManagerV2 } from "../src/contracts/ProtocolAccessManagerV2.sol";
import { IAccessControlErrors } from "../src/interfaces/IAccessControlErrors.sol";
import { Test } from "forge-std/Test.sol";

// Mock consumer contract (e.g., a new FleetCommander)
contract MockFleetV2 is ProtocolAccessManagedV2 {

    constructor(address accessManager) ProtocolAccessManagedV2(accessManager) { }

    function restrictedAction() external onlyOperator returns (bool) {
        return true;
    }

}

contract ProtocolAccessManagedV2Test is Test {

    ProtocolAccessManagerV2 public accessManager;
    MockFleetV2 public fleet;

    address public admin = address(0x1);
    address public operator = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.prank(admin);
        accessManager = new ProtocolAccessManagerV2(admin);
        fleet = new MockFleetV2(address(accessManager));
    }

    function test_Constructor_FailsWithV1Manager() public {
        // Assuming we have a way to deploy a standard V1 AM that doesn't support IProtocolAccessManagerV2
        // We'll mock the address to revert on the ERC165 check
        address fakeV1 = address(0x12345);
        vm.mockCall(fakeV1, abi.encodeWithSignature("supportsInterface(bytes4)"), abi.encode(false));

        vm.expectRevert(abi.encodeWithSelector(IAccessControlErrors.InvalidAccessManagerAddress.selector, fakeV1));
        new MockFleetV2(fakeV1);
    }

    function test_OnlyOperator_Modifier() public {
        // Grant role to operator for THIS specific fleet
        vm.prank(admin);
        accessManager.grantOperatorRole(address(fleet), operator);

        // Operator succeeds
        vm.prank(operator);
        assertTrue(fleet.restrictedAction());

        // Normal user fails
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IAccessControlErrors.CallerIsNotOperator.selector, user));
        fleet.restrictedAction();
    }

    function test_HasOperatorRole_View() public {
        vm.prank(admin);
        accessManager.grantOperatorRole(address(fleet), operator);

        assertTrue(fleet.hasOperatorRole(operator));
        assertFalse(fleet.hasOperatorRole(user));
    }

}
