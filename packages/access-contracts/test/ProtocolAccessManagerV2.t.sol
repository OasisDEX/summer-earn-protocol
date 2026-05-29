// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManagerV2} from "../src/contracts/ProtocolAccessManagerV2.sol";
import {IAccessControlErrors} from "../src/interfaces/IAccessControlErrors.sol";
import {ContractSpecificRoles} from "../src/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../src/interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "../src/interfaces/IProtocolAccessManagerV2.sol";
import {Test} from "forge-std/Test.sol";

contract ProtocolAccessManagerV2Test is Test, IAccessControlErrors {
    ProtocolAccessManagerV2 public accessManager;
    address public governor = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public contextA = address(0x5);
    address public contextB = address(0x6);
    address public operator = address(0x7);

    // Re-declare events for expectEmit
    event WhitelistStatusUpdated(
        address indexed context,
        address indexed account,
        bool isWhitelisted
    );
    event WhitelistOpenUpdated(address indexed context, bool isOpen);

    // Access to V2 errors
    error Whitelist_LengthMismatch();
    error Whitelist_BatchTooLarge();

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
        assertTrue(
            accessManager.supportsInterface(
                type(IProtocolAccessManager).interfaceId
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                            OPERATOR ROLE
    //////////////////////////////////////////////////////////////*/

    function test_GrantOperatorRole() public {
        vm.prank(governor);
        accessManager.grantOperatorRole(contextA, operator);

        bytes32 role = accessManager.generateRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            contextA
        );
        assertTrue(accessManager.hasRole(role, operator));

        // Ensure isolation
        bytes32 roleB = accessManager.generateRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            contextB
        );
        assertFalse(accessManager.hasRole(roleB, operator));
    }

    function test_RevokeOperatorRole() public {
        vm.startPrank(governor);
        accessManager.grantOperatorRole(contextA, operator);
        accessManager.revokeOperatorRole(contextA, operator);
        vm.stopPrank();

        bytes32 role = accessManager.generateRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            contextA
        );
        assertFalse(accessManager.hasRole(role, operator));
    }

    function test_OperatorRole_Revert_NotGovernor() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, user1)
        );
        accessManager.grantOperatorRole(contextA, operator);
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELIST MANAGER ROLE
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

    function test_RevokeWhitelistManagerRole() public {
        vm.startPrank(governor);
        accessManager.grantWhitelistManagerRole(manager);
        accessManager.revokeWhitelistManagerRole(manager);
        vm.stopPrank();
        assertFalse(
            accessManager.hasRole(
                accessManager.WHITELIST_MANAGER_ROLE(),
                manager
            )
        );
    }

    function test_WhitelistManagerRole_Revert_NotGovernor() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, user1)
        );
        accessManager.grantWhitelistManagerRole(manager);
    }

    /*//////////////////////////////////////////////////////////////
                            WHITELISTING
    //////////////////////////////////////////////////////////////*/

    function test_isWhitelisted_Explicit() public {
        vm.prank(governor);
        accessManager.setWhitelisted(contextA, user1, true);

        assertTrue(accessManager.isWhitelisted(contextA, user1));
        assertFalse(accessManager.isWhitelisted(contextA, user2));

        // Context Isolation
        assertFalse(accessManager.isWhitelisted(contextB, user1));
    }

    function test_isWhitelisted_OpenMode() public {
        vm.prank(governor);
        accessManager.setWhitelistOpen(contextA, true);

        assertTrue(accessManager.isWhitelistOpen(contextA));
        assertTrue(accessManager.isWhitelisted(contextA, user1));
        assertTrue(accessManager.isWhitelisted(contextA, user2));

        // Ensure isolation
        assertFalse(accessManager.isWhitelistOpen(contextB));
        assertFalse(accessManager.isWhitelisted(contextB, user1));
    }

    function test_isWhitelisted_ClosedMode() public {
        assertFalse(accessManager.isWhitelisted(contextA, user1));
    }

    function test_SetWhitelisted_Idempotency() public {
        vm.startPrank(governor);

        // First time sets and emits event
        vm.expectEmit(true, true, false, true);
        emit WhitelistStatusUpdated(contextA, user1, true);
        accessManager.setWhitelisted(contextA, user1, true);

        // Second time (same value) should NOT emit event
        accessManager.setWhitelisted(contextA, user1, true);

        assertTrue(accessManager.isWhitelisted(contextA, user1));
        vm.stopPrank();
    }

    function test_SetWhitelistOpen_Idempotency() public {
        vm.startPrank(governor);

        vm.expectEmit(true, false, false, true);
        emit WhitelistOpenUpdated(contextA, true);
        accessManager.setWhitelistOpen(contextA, true);

        // Should not emit again
        accessManager.setWhitelistOpen(contextA, true);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            BATCH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function test_areWhitelisted() public {
        vm.startPrank(governor);
        accessManager.setWhitelisted(contextA, user1, true);
        // user2 remains false
        vm.stopPrank();

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        bool[] memory statuses = accessManager.areWhitelisted(contextA, users);
        assertTrue(statuses[0]);
        assertFalse(statuses[1]);

        // Test Open Mode in batch
        vm.prank(governor);
        accessManager.setWhitelistOpen(contextA, true);

        statuses = accessManager.areWhitelisted(contextA, users);
        assertTrue(statuses[0]);
        assertTrue(statuses[1]);
    }

    function test_setWhitelistedBatch() public {
        address[] memory users = new address[](3);
        users[0] = address(0x10);
        users[1] = address(0x11);
        users[2] = address(0x12);

        bool[] memory statuses = new bool[](3);
        statuses[0] = true;
        statuses[1] = false;
        statuses[2] = true;

        vm.prank(governor);
        accessManager.setWhitelistedBatch(contextA, users, statuses);

        assertTrue(accessManager.isWhitelisted(contextA, users[0]));
        assertFalse(accessManager.isWhitelisted(contextA, users[1]));
        assertTrue(accessManager.isWhitelisted(contextA, users[2]));
    }

    function test_SetWhitelistedBatch_Revert_LengthMismatch() public {
        address[] memory users = new address[](2);
        users[0] = address(0x10);
        users[1] = address(0x11);

        bool[] memory statuses = new bool[](3);
        statuses[0] = true;
        statuses[1] = true;
        statuses[2] = true;

        vm.prank(governor);
        vm.expectRevert(
            IProtocolAccessManagerV2.Whitelist_LengthMismatch.selector
        );
        accessManager.setWhitelistedBatch(contextA, users, statuses);
    }

    function test_SetWhitelistedBatch_Revert_BatchTooLarge() public {
        uint256 size = accessManager.MAX_WHITELIST_BATCH_SIZE() + 1;
        address[] memory users = new address[](size);
        bool[] memory statuses = new bool[](size);

        for (uint256 i = 0; i < size; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            users[i] = address(uint160(i + 100));
            statuses[i] = true;
        }

        vm.prank(governor);
        vm.expectRevert(
            IProtocolAccessManagerV2.Whitelist_BatchTooLarge.selector
        );
        accessManager.setWhitelistedBatch(contextA, users, statuses);
    }

    function test_GlobalWhitelistOpen() public {
        // address(0) = true opens the whitelist for everyone
        vm.prank(governor);
        accessManager.setWhitelistOpen(contextA, true);

        bool isRandomUserWhitelisted = accessManager.isWhitelisted(
            contextA,
            address(12345)
        );
        bool isWhitelistOpen = accessManager.isWhitelistOpen(contextA);
        assertTrue(isRandomUserWhitelisted);
        assertTrue(isWhitelistOpen);
    }

    function test_setWhitelistedBatch_Revert_Empty() public {
        address[] memory users = new address[](0);
        bool[] memory statuses = new bool[](0);

        vm.prank(governor);
        vm.expectRevert(Whitelist_LengthMismatch.selector);
        accessManager.setWhitelistedBatch(contextA, users, statuses);
    }

    function test_setWhitelistedBatch_Revert_TooLarge() public {
        uint256 size = accessManager.MAX_WHITELIST_BATCH_SIZE() + 1;
        address[] memory users = new address[](size);
        bool[] memory statuses = new bool[](size);

        vm.prank(governor);
        vm.expectRevert(Whitelist_BatchTooLarge.selector);
        accessManager.setWhitelistedBatch(contextA, users, statuses);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function test_WhitelistSetters_Revert_NotManager() public {
        vm.startPrank(user1);

        vm.expectRevert(); // WHITELIST_MANAGER_ROLE check
        accessManager.setWhitelisted(contextA, user2, true);

        vm.expectRevert();
        accessManager.setWhitelistOpen(contextA, true);

        address[] memory u = new address[](1);
        u[0] = user2;
        bool[] memory s = new bool[](1);
        s[0] = true;
        vm.expectRevert();
        accessManager.setWhitelistedBatch(contextA, u, s);

        vm.stopPrank();
    }
}
