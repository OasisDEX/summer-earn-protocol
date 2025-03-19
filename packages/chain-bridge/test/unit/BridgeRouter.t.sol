// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeAdapter} from "../../src/adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";

contract BridgeRouterTest is Test {
    BridgeRouter public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    MockERC20 public token;

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
        mockAdapter2 = new MockAdapter(address(router));
        token = new MockERC20("Test Token", "TEST");

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

    // ---- ADAPTER MANAGEMENT TESTS ----

    function testRegisterAdapter() public {
        vm.startPrank(admin);

        // Register second adapter
        assertFalse(router.adapters(address(mockAdapter2)));
        router.registerAdapter(address(mockAdapter2));
        assertTrue(router.adapters(address(mockAdapter2)));

        vm.stopPrank();
    }

    function testRegisterAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-admin tries to register adapter
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.registerAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testRegisterDuplicateAdapter() public {
        vm.startPrank(admin);

        // Should revert when registering same adapter twice
        vm.expectRevert(BridgeRouter.AdapterAlreadyRegistered.selector);
        router.registerAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveAdapter() public {
        vm.startPrank(admin);

        // Remove adapter
        assertTrue(router.adapters(address(mockAdapter)));
        router.removeAdapter(address(mockAdapter));
        assertFalse(router.adapters(address(mockAdapter)));

        vm.stopPrank();
    }

    function testRemoveAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-admin tries to remove adapter
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.removeAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveNonExistentAdapter() public {
        vm.startPrank(admin);

        // Should revert when removing non-existent adapter
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.removeAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testGetAdapters() public {
        vm.startPrank(admin);

        // Register second adapter
        router.registerAdapter(address(mockAdapter2));

        // Get adapters
        address[] memory adapterList = router.getAdapters();
        assertEq(adapterList.length, 2);
        assertEq(adapterList[0], address(mockAdapter));
        assertEq(adapterList[1], address(mockAdapter2));

        vm.stopPrank();
    }

    // ---- TRANSFER ASSET TESTS ----

    function testSend() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0, // Lowest cost
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Send transfer
        bytes32 transferId = router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        // Verify transfer was initiated
        assertEq(
            router.transferStatuses(transferId),
            uint8(BridgeTypes.TransferStatus.PENDING)
        );
        assertEq(router.transferToAdapter(transferId), address(mockAdapter));

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
            adapterParams: ""
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

    function testSendInvalidParams() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Should revert with zero amount
        vm.expectRevert(BridgeRouter.InvalidParams.selector);
        router.transferAssets(DEST_CHAIN_ID, address(token), 0, user, options);

        // Should revert with zero recipient
        vm.expectRevert(BridgeRouter.InvalidParams.selector);
        router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            address(0),
            options
        );

        vm.stopPrank();
    }

    function testSendNoSuitableAdapter() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Unsupported destination chain
        vm.expectRevert(BridgeRouter.NoSuitableAdapter.selector);
        router.transferAssets(
            999, // Unsupported chain ID
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        vm.stopPrank();
    }

    // ---- READ STATE TESTS ----

    function testReadState() public {
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Read state
        bytes32 requestId = router.readState(
            DEST_CHAIN_ID,
            address(0x123),
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user),
            options
        );

        // Verify request was initiated
        assertEq(
            router.transferStatuses(requestId),
            uint8(BridgeTypes.TransferStatus.PENDING)
        );
        assertEq(router.transferToAdapter(requestId), address(mockAdapter));
        assertEq(router.readRequestToOriginator(requestId), user);

        vm.stopPrank();
    }

    function testDeliverReadResponse() public {
        // First create a read request
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Read state
        bytes32 requestId = router.readState(
            DEST_CHAIN_ID,
            address(0x123),
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user),
            options
        );

        vm.stopPrank();

        // Now deliver the response from the adapter
        vm.prank(address(mockAdapter));
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));

        // Verify response was delivered
        assertEq(
            router.transferStatuses(requestId),
            uint8(BridgeTypes.TransferStatus.DELIVERED)
        );
    }

    function testDeliverReadResponseUnauthorized() public {
        // First create a read request
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Read state
        bytes32 requestId = router.readState(
            DEST_CHAIN_ID,
            address(0x123),
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user),
            options
        );

        vm.stopPrank();

        // Should revert when non-adapter tries to deliver response
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));

        // Should revert when wrong adapter tries to deliver response
        vm.startPrank(admin);
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        vm.prank(address(mockAdapter2));
        vm.expectRevert(BridgeRouter.Unauthorized.selector);
        router.deliverReadResponse(requestId, abi.encode(uint256(100)));
    }

    // ---- ADAPTER SELECTION TESTS ----

    function testGetBestAdapter() public {
        // Setup second adapter with different fee
        vm.startPrank(admin);
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter2.setSupportedAsset(DEST_CHAIN_ID, address(token), true);
        mockAdapter2.setFeeMultiplier(150); // 50% more expensive
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        // Get best adapter for lowest cost
        address bestAdapter = router.getBestAdapter(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            0 // Lowest cost preference
        );

        // Should select the cheaper adapter
        assertEq(bestAdapter, address(mockAdapter));

        // Test other preferences when implemented
    }

    // ---- FEE ESTIMATION TESTS ----

    function testQuote() public {
        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Get quote
        (uint256 nativeFee, uint256 tokenFee, address selectedAdapter) = router
            .quote(DEST_CHAIN_ID, address(token), TRANSFER_AMOUNT, options);

        // Verify quote
        assertEq(selectedAdapter, address(mockAdapter));
        assertTrue(nativeFee > 0);
        // Add more assertions based on mock implementation
    }

    function testQuoteNoSuitableAdapter() public {
        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Should revert for unsupported chain
        vm.expectRevert(BridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            999, // Unsupported chain ID
            address(token),
            TRANSFER_AMOUNT,
            options
        );
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

    function testUpdateTransferStatus() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Send transfer
        bytes32 transferId = router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        vm.stopPrank();

        // Update status from adapter
        vm.prank(address(mockAdapter));
        router.updateTransferStatus(
            transferId,
            BridgeTypes.TransferStatus.DELIVERED
        );

        // Verify status was updated
        assertEq(
            router.transferStatuses(transferId),
            uint8(BridgeTypes.TransferStatus.DELIVERED)
        );
    }

    function testUpdateTransferStatusUnauthorized() public {
        vm.startPrank(user);

        // Approve tokens
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            feeToken: address(0),
            bridgePreference: 0,
            gasLimit: 500000,
            refundAddress: user,
            adapterParams: ""
        });

        // Send transfer
        bytes32 transferId = router.transferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );

        // Should revert when non-adapter tries to update status
        vm.expectRevert(BridgeRouter.UnknownAdapter.selector);
        router.updateTransferStatus(
            transferId,
            BridgeTypes.TransferStatus.DELIVERED
        );

        vm.stopPrank();
    }
}
