// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

import {MockAdapter} from "../mocks/MockAdapter.sol";

import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

contract BridgeRouterAdaptersTest is BridgeRouterSetup {
    // ---- ADAPTER MANAGEMENT TESTS ----

    function testRegisterAdapter() public {
        vm.startPrank(governor);

        // Register second adapter (use mockAdapterDest)
        assertFalse(router.isValidAdapter(address(mockAdapterDest)));
        router.registerAdapter(address(mockAdapterDest));
        assertTrue(router.isValidAdapter(address(mockAdapterDest)));

        vm.stopPrank();
    }

    function testRegisterAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-governor tries to register adapter
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.registerAdapter(address(mockAdapterDest));

        vm.stopPrank();
    }

    function testRegisterDuplicateAdapter() public {
        vm.startPrank(governor);

        // Should revert when registering same adapter twice
        vm.expectRevert(IBridgeRouter.AdapterAlreadyRegistered.selector);
        router.registerAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveAdapter() public {
        vm.startPrank(governor);

        // Remove adapter
        assertTrue(router.isValidAdapter(address(mockAdapter)));
        router.removeAdapter(address(mockAdapter));
        assertFalse(router.isValidAdapter(address(mockAdapter)));

        vm.stopPrank();
    }

    function testRemoveAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-governor tries to remove adapter
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.removeAdapter(address(mockAdapter));

        vm.stopPrank();
    }

    function testRemoveNonExistentAdapter() public {
        vm.startPrank(governor);

        // Should revert when removing non-existent adapter
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.removeAdapter(address(mockAdapterDest));

        vm.stopPrank();
    }

    function testGetAdapters() public {
        vm.startPrank(governor);

        // Register second adapter
        router.registerAdapter(address(mockAdapterDest));

        // Get adapters
        address[] memory adapterList = router.getAdapters();
        assertEq(adapterList.length, 2);
        assertEq(adapterList[0], address(mockAdapter));
        assertEq(adapterList[1], address(mockAdapterDest));

        vm.stopPrank();
    }

    // ---- ADAPTER SPECIFICATION TESTS ----

    function testSpecifiedAdapter() public {
        vm.startPrank(governor);
        // Configure mockAdapterDest to support the destination chain and asset
        mockAdapterDest.setSupportedChain(DEST_CHAIN_ID, true);

        // Register second adapter
        router.registerAdapter(address(mockAdapterDest));
        vm.stopPrank();

        vm.startPrank(user);

        // Create bridge options with specified adapter
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapterDest),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Get the required fee first (using router.quote) FOR EXECUTION
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        vm.stopPrank();

        vm.startPrank(executor);
        // approve tokens for transfer
        token.approve(address(router), TRANSFER_AMOUNT);

        bytes32 operationId = router.executeTransferAssets{value: nativeFee}(
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                target: user,
                originator: executor,
                refundAddress: address(executor),
                message: ""
            }),
            options
        );
        vm.stopPrank();
    }

    function testInvalidSpecifiedAdapter() public {
        vm.startPrank(user);

        // Create bridge options with invalid adapter
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0x123),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Get the required fee first. This quote call should revert.
        // The check happens in the router during quoting.
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Since quote reverts, queueing would also fail if it depends on a valid quote,
        // or the execution would fail if the check is deferred.
        // Let's keep the check on quote as it's the first point of failure.

        vm.stopPrank();
    }

    function testAdapterValidation() public {
        // Register multiple adapters with different support combinations
        vm.startPrank(governor);

        // Setup second adapter
        mockAdapterDest.setSupportedChain(DEST_CHAIN_ID, true);
        router.registerAdapter(address(mockAdapterDest));

        // Create an adapter that doesn't support the chain
        MockAdapter unsupportedChainAdapter = new MockAdapter(
            address(registry),
            address(accessManager)
        );
        unsupportedChainAdapter.setSupportedChain(DEST_CHAIN_ID, false);
        router.registerAdapter(address(unsupportedChainAdapter));

        vm.stopPrank();

        // Create adapter params for testing
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 0,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Test 1: Valid adapter that supports everything
        (, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        assertEq(
            specifiedAdapter,
            address(mockAdapter),
            "Should return the specified valid adapter"
        );

        // Test 2: Adapter that doesn't support the chain - should fail at estimateFee level
        options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(unsupportedChainAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        vm.expectRevert(); // Will revert with UnsupportedChain from estimateFee
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Test 3: Unregistered adapter
        options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0x999),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Test 4: No adapter specified
        options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        options.specifiedAdapter = address(mockAdapter);
        // Test 5: Valid adapter with different token (MockAdapter supports any token)
        ERC20Mock newToken = new ERC20Mock();
        (, , address specifiedAdapterForNewToken) = router.quote(
            DEST_CHAIN_ID,
            address(newToken),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        assertEq(
            specifiedAdapterForNewToken,
            address(mockAdapter),
            "Should return specified adapter for any supported token"
        );
    }

    // ---- FEE ESTIMATION TESTS ----

    function testQuote() public view {
        // Create bridge options with explicit adapter
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Get quote
        (uint256 nativeFee, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Verify quote
        assertEq(specifiedAdapter, address(mockAdapter));
        assertTrue(nativeFee > 0);
    }

    function testQuoteNoSuitableAdapter() public {
        // Create bridge options with no adapter specified
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        // Should revert when no adapter is specified
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }
}
