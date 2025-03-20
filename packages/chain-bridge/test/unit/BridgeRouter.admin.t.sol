// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeAdapter} from "../../src/adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";

contract BridgeRouterAdminTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    ERC20Mock public token;

    address public admin = address(0x1);
    address public user = address(0x2);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        router = new BridgeRouter();
        mockAdapter = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(admin, 10000e18);
        token.mint(user, 10000e18);

        vm.stopPrank();
    }

    // ---- ADMIN FUNCTION TESTS ----

    function testPause() public {
        vm.startPrank(admin);

        // Pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Unpause
        router.unpause();
        assertFalse(router.paused());

        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-admin tries to pause
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.pause();

        vm.stopPrank();
    }

    function testSetAdmin() public {
        vm.startPrank(admin);

        // Set new admin
        assertEq(router.admin(), admin);
        router.setAdmin(user);
        assertEq(router.admin(), user);

        vm.stopPrank();
    }

    function testSetAdminUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-admin tries to set admin
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.setAdmin(user);

        vm.stopPrank();
    }

    function testSendWhenPaused() public {
        // Pause the router
        vm.prank(admin);
        router.pause();

        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: "",
            specifiedAdapter: address(0) // Auto-select
        });

        // Should revert when router is paused
        vm.expectRevert(BridgeRouter.Paused.selector);
        router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        vm.stopPrank();
    }
}
