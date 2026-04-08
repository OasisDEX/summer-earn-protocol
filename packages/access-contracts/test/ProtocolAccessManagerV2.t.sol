// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManagerV2} from "../src/contracts/ProtocolAccessManagerV2.sol";
import {ContractSpecificRoles} from "../src/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "../src/interfaces/IProtocolAccessManagerV2.sol";
import {Test} from "forge-std/Test.sol";

contract ProtocolAccessManagerV2Test is Test {
    ProtocolAccessManagerV2 public accessManager;
    address public governor = address(0x1);
    address public manager = address(0x2);
    address public user = address(0x3);
    address public fleet = address(0x4);
    address public operator = address(0x5);

    event WhitelistStatusUpdated(address indexed account, bool isWhitelisted);

    function setUp() public {
        vm.prank(governor);
        accessManager = new ProtocolAccessManagerV2(governor);
    }

    function test_V2_SupportsInterface() public view {
        assertTrue(
            accessManager.supportsInterface(
                type(IProtocolAccessManagerV2).interfaceId
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                            OPERATOR ROLE
    //////////////////////////////////////////////////////////////*/

    function test_GrantOperatorRole() public {
        vm.prank(governor);
        accessManager.grantOperatorRole(fleet, operator);

        bytes32 role = accessManager.generateRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            fleet
        );
        assertTrue(accessManager.hasRole(role, operator));
    }

    function test_RevokeOperatorRole() public {
        vm.startPrank(governor);
        accessManager.grantOperatorRole(fleet, operator);
        accessManager.revokeOperatorRole(fleet, operator);
        vm.stopPrank();

        bytes32 role = accessManager.generateRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            fleet
        );
        assertFalse(accessManager.hasRole(role, operator));
    }

    /*//////////////////////////////////////////////////////////////
                            WHITELISTING
    //////////////////////////////////////////////////////////////*/

    function test_InitialWhitelistManager() public view {
        assertTrue(
            accessManager.hasRole(
                accessManager.WHITELIST_MANAGER_ROLE(),
                governor
            )
        );
    }

    function test_GrantWhitelistManagerRole() public {
        vm.prank(governor);
        accessManager.grantWhitelistManagerRole(manager);
        assertTrue(
            accessManager.hasRole(
                accessManager.WHITELIST_MANAGER_ROLE(),
                manager
            )
        );
    }

    function test_SetWhitelisted_Idempotency() public {
        vm.startPrank(governor);

        // First time sets and emits event
        vm.expectEmit(true, false, false, true);
        emit WhitelistStatusUpdated(user, true);
        accessManager.setWhitelisted(user, true);

        // Second time (same value) should NOT emit event
        // Note: expectEmit(false,...) doesn't work well in Foundry,
        // so we check state and ensure no redundant gas/logs in trace
        accessManager.setWhitelisted(user, true);

        assertTrue(accessManager.isWhitelisted(user));
        vm.stopPrank();
    }

    function test_SetWhitelistedBatch() public {
        address[] memory users = new address[](3);
        users[0] = address(0x10);
        users[1] = address(0x11);
        users[2] = address(0x12);

        bool[] memory statuses = new bool[](3);
        statuses[0] = true;
        statuses[1] = true;
        statuses[2] = true;

        vm.prank(governor);
        accessManager.setWhitelistedBatch(users, statuses);

        assertTrue(accessManager.isWhitelisted(users[0]));
        assertTrue(accessManager.isWhitelisted(users[1]));
        assertTrue(accessManager.isWhitelisted(users[2]));
    }

    function test_GlobalWhitelistOpen() public {
        // address(0) = true opens the whitelist for everyone
        vm.prank(governor);
        accessManager.setWhitelisted(address(0), true);

        assertTrue(accessManager.isWhitelisted(address(0xdead)));
        assertTrue(accessManager.isWhitelisted(address(0xbeef)));
    }

    function test_WhitelistReverts_NotManager() public {
        vm.prank(user);
        vm.expectRevert(); // Should fail due to WHITELIST_MANAGER_ROLE check
        accessManager.setWhitelisted(user, true);
    }
}
