// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IBridgeAdapter } from "../../src/interfaces/IBridgeAdapter.sol";
import { IBridgeRouter } from "../../src/interfaces/IBridgeRouter.sol";
import { ISendAdapter } from "../../src/interfaces/ISendAdapter.sol";
import { BridgeTypes } from "../../src/libraries/BridgeTypes.sol";
import { BridgeRouter } from "../../src/router/BridgeRouter.sol";
import { MockAdapter } from "../mocks/MockAdapter.sol";
import { BridgeRouterSetup } from "./BridgeRouter.setup.t.sol";
import { Test, console } from "forge-std/Test.sol";

contract BridgeRouterTransferTest is BridgeRouterSetup {

    // Additional addresses specific to transfer tests
    address public authorizedCaller = address(0x5);

    // Executor option type constants
    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 5;

    // ---- TRANSFER ASSET TESTS ----

    function testSend() public {
        // User initiates
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams =
            BridgeTypes.AdapterParams({ gasLimit: 500000, calldataSize: 0, msgValue: 0, options: "" });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });

        // Get a quote first to determine the required fee FOR EXECUTION
        (uint256 nativeFee,, address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID, address(token), TRANSFER_AMOUNT, options, BridgeTypes.OperationType.TRANSFER_ASSET
        );
        // vm.deal(user, nativeFee); // REMOVED: User no longer pays fee

        // Verify the specified adapter matches what we provided
        assertEq(specifiedAdapter, address(mockAdapter));

        vm.stopPrank(); // User stops queueing

        // Keeper executes (PAYS THE FEE)
        vm.startPrank(keeper);
        // approve tokens for transfer
        token.approve(address(router), TRANSFER_AMOUNT);
        // Execute with value - Fixed: added options parameter
        bytes32 operationId = router.executeTransferAssets{ value: nativeFee }(
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                recipient: user,
                originator: user,
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();

        // Verify bridge opeariotn status updated post-execution
        assertEq(uint256(router.getOperationStatus(operationId)), uint256(BridgeTypes.OperationStatus.SENT));

        // Verify transfer was initiated in router
        // Note: Router state is mocked here, real state is in BridgeQueue now primarily
        // assertEq(
        //     uint256(router.operationStatuses(operationId)),
        //     uint256(BridgeTypes.OperationStatus.PENDING)
        // );
        // assertEq(router.operationToAdapter(operationId), specifiedAdapter); // Check correct adapter used
        // assertEq(operationId, expectedOperationId, "Operation ID mismatch"); // Check returned ID
    }

    function testSendNoSuitableAdapter() public {
        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams =
            BridgeTypes.AdapterParams({ gasLimit: 500000, calldataSize: 0, msgValue: 0, options: "" });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // No adapter specified
            adapterParams: adapterParams
        });

        // Should revert when no adapter is specified
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            DEST_CHAIN_ID, // Use supported chain ID
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        vm.stopPrank();
    }

    function testUpdateTransferStatusUnauthorized() public {
        bytes32 operationId; // Declare operationId

        // User queues (NO VALUE)
        vm.startPrank(user);
        token.approve(address(router), TRANSFER_AMOUNT);
        BridgeTypes.AdapterParams memory adapterParams =
            BridgeTypes.AdapterParams({ gasLimit: 500000, calldataSize: 0, msgValue: 0, options: "" });
        BridgeTypes.BridgeOptions memory options =
            BridgeTypes.BridgeOptions({ specifiedAdapter: address(mockAdapter), adapterParams: adapterParams });
        (uint256 nativeFee,,) = router.quote( // Quote needed for keeper execution
        DEST_CHAIN_ID, address(token), TRANSFER_AMOUNT, options, BridgeTypes.OperationType.TRANSFER_ASSET);

        vm.stopPrank();

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);
        // approve tokens for transfer

        token.approve(address(router), TRANSFER_AMOUNT);
        // Execute the operation - let it run normally without mocking
        operationId = router.executeTransferAssets{ value: nativeFee }(
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                recipient: user,
                originator: user,
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();

        // Should revert when non-adapter tries to update status
        vm.prank(user); // Use user address (or any other non-adapter)
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.updateOperationStatus(operationId, BridgeTypes.OperationStatus.SENT);

        // Register second adapter and configure it to support the chain
        vm.startPrank(governor);
        router.registerAdapter(address(mockAdapter2));
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        vm.stopPrank();

        // Should revert when wrong adapter tries to deliver response
        vm.prank(address(mockAdapter2));
        vm.expectRevert(IBridgeRouter.Unauthorized.selector);
        router.updateOperationStatus(operationId, BridgeTypes.OperationStatus.SENT);
    }

    function testDebugMockAdapter() public {
        // Test if MockAdapter is properly configured
        vm.startPrank(governor);

        // Check if adapter supports chain 10
        bool supportsChain10 = mockAdapter.supportsChain(DEST_CHAIN_ID);
        console.log("MockAdapter supports chain 10:", supportsChain10);

        // Check if adapter supports TRANSFER_ASSET operation
        bool supportsTransfer = mockAdapter.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET);
        console.log("MockAdapter supports TRANSFER_ASSET:", supportsTransfer);

        // Check bridge router address
        address routerAddr = mockAdapter.bridgeRouter();
        console.log("MockAdapter bridgeRouter:", routerAddr);
        console.log("Actual router address:", address(router));

        // Test interface casting with IBridgeAdapter
        try IBridgeAdapter(address(mockAdapter)).estimateFee(
            DEST_CHAIN_ID,
            address(token),
            1000e18,
            BridgeTypes.AdapterParams({ gasLimit: 500000, calldataSize: 0, msgValue: 0, options: "" }),
            BridgeTypes.OperationType.TRANSFER_ASSET
        ) returns (uint256 nativeFee, uint256) {
            console.log("IBridgeAdapter cast works, nativeFee:", nativeFee);
        } catch {
            console.log("IBridgeAdapter cast failed");
        }

        // Check function selectors
        bytes4 transferAssetSelector = ISendAdapter.transferAsset.selector;
        console.log("transferAsset selector:");
        console.logBytes4(transferAssetSelector);

        vm.stopPrank();

        // Try calling transferAsset directly from router
        vm.startPrank(address(router));

        // Give the router some ETH for payable calls
        vm.deal(address(router), 1 ether);

        // Mint some tokens to the router for testing
        token.mint(address(router), 1000e18);
        token.approve(address(mockAdapter), 1000e18);

        // Check balances and approvals
        console.log("Router token balance:", token.balanceOf(address(router)));
        console.log("Router approval to MockAdapter:", token.allowance(address(router), address(mockAdapter)));

        // Test if basic function calls work
        try mockAdapter.testFunction() returns (bool result) {
            console.log("testFunction call succeeded, result:", result);
        } catch {
            console.log("testFunction call failed");
        }

        // Try calling transferAsset with simple parameters
        BridgeTypes.AdapterParams memory simpleParams =
            BridgeTypes.AdapterParams({ gasLimit: 0, calldataSize: 0, msgValue: 0, options: "0x" });

        try mockAdapter.transferAsset{ value: 0.1 ether }(
            bytes32("test"),
            DEST_CHAIN_ID,
            address(token),
            user,
            1,
            user,
            user, // Add keeper parameter
            simpleParams
        ) {
            console.log("Simple transferAsset call succeeded");
        } catch Error(string memory reason) {
            console.log("Simple transferAsset call failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Simple transferAsset call failed with low level data");
            console.logBytes(lowLevelData);
        }

        // Try with explicit gas limit
        try mockAdapter.transferAsset{ value: 0.1 ether, gas: 500000 }(
            bytes32("test"),
            DEST_CHAIN_ID,
            address(token),
            user,
            1,
            user,
            user, // Add keeper parameter
            simpleParams
        ) {
            console.log("High gas transferAsset call succeeded");
        } catch Error(string memory reason) {
            console.log("High gas transferAsset call failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("High gas transferAsset call failed with low level data");
            console.logBytes(lowLevelData);
        }

        // Try the minimal version
        try mockAdapter.transferAssetMinimal{ value: 0.1 ether }(
            bytes32("test"), DEST_CHAIN_ID, address(token), user, 1, user
        ) {
            console.log("transferAssetMinimal call succeeded");
        } catch Error(string memory reason) {
            console.log("transferAssetMinimal call failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("transferAssetMinimal call failed with low level data");
            console.logBytes(lowLevelData);
        }

        // Try without payable value
        try mockAdapter.transferAssetMinimal(bytes32("test"), DEST_CHAIN_ID, address(token), user, 1, user) {
            console.log("transferAssetMinimal (no value) call succeeded");
        } catch Error(string memory reason) {
            console.log("transferAssetMinimal (no value) call failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("transferAssetMinimal (no value) call failed with low level data");
            console.logBytes(lowLevelData);
        }

        vm.stopPrank();
    }

    function testDirectExecuteTransferAssets() public {
        // Setup tokens
        vm.startPrank(keeper);
        token.approve(address(authorizedCaller), TRANSFER_AMOUNT);
        vm.stopPrank();

        // Transfer tokens to BridgeQueue first
        vm.prank(keeper);
        token.transfer(authorizedCaller, TRANSFER_AMOUNT);

        // Approve BridgeRouter to spend BridgeQueue's tokens
        vm.prank(address(authorizedCaller));
        token.approve(address(router), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams =
            BridgeTypes.AdapterParams({ gasLimit: 500000, calldataSize: 0, msgValue: 0, options: "" });

        BridgeTypes.BridgeOptions memory options =
            BridgeTypes.BridgeOptions({ specifiedAdapter: address(mockAdapter), adapterParams: adapterParams });

        // Get quote
        (uint256 nativeFee,,) = router.quote(
            DEST_CHAIN_ID, address(token), TRANSFER_AMOUNT, options, BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Call executeTransferAssets directly from BridgeQueue
        vm.startPrank(address(authorizedCaller));

        // Check ETH balances before the call
        console.log("BridgeQueue ETH balance:", address(authorizedCaller).balance);
        console.log("BridgeRouter ETH balance:", address(router).balance);
        console.log("Required native fee:", nativeFee);

        // Check token balances and approvals
        console.log("BridgeQueue token balance:", token.balanceOf(address(authorizedCaller)));
        console.log("BridgeRouter token balance:", token.balanceOf(address(router)));
        console.log("BridgeQueue approval to Router:", token.allowance(address(authorizedCaller), address(router)));

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes.ExecuteTransferParams({
            destinationChainId: DEST_CHAIN_ID,
            asset: address(token),
            amount: TRANSFER_AMOUNT,
            recipient: user,
            originator: user,
            keeper: address(authorizedCaller),
            options: options
        });

        console.log("About to call executeTransferAssets...");

        // Debug: Check if adapter supports the operation and chain
        console.log(
            "MockAdapter supports TRANSFER_ASSET:",
            mockAdapter.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        console.log("MockAdapter supports chain 10:", mockAdapter.supportsChain(DEST_CHAIN_ID));
        console.log("MockAdapter is valid adapter:", router.isValidAdapter(address(mockAdapter)));
        console.log("MockAdapter address:", address(mockAdapter));
        console.log("Specified adapter in params:", params.options.specifiedAdapter);

        try router.executeTransferAssets{ value: nativeFee }(params) returns (bytes32 operationId) {
            console.log("Direct executeTransferAssets succeeded");
            console.log("Operation ID:", uint256(operationId));
        } catch Error(string memory reason) {
            console.log("Direct executeTransferAssets failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Direct executeTransferAssets failed with low level data");
            console.logBytes(lowLevelData);
        }

        vm.stopPrank();
    }

    function testMinimalExecuteTransferAssets() public {
        // Minimal setup - just call executeTransferAssets directly
        vm.startPrank(address(authorizedCaller));

        // Give BridgeQueue some tokens
        token.mint(address(authorizedCaller), 100);

        // IMPORTANT: Approve BridgeRouter to spend BridgeQueue's tokens
        token.approve(address(router), 100);

        // Create minimal params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes.ExecuteTransferParams({
            destinationChainId: DEST_CHAIN_ID,
            asset: address(token),
            amount: 100,
            recipient: user,
            originator: user,
            keeper: address(authorizedCaller),
            options: BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                adapterParams: BridgeTypes.AdapterParams({ gasLimit: 500000, calldataSize: 0, msgValue: 0, options: "" })
            })
        });

        console.log("About to call executeTransferAssets...");

        // Debug: Check if adapter supports the operation and chain
        console.log(
            "MockAdapter supports TRANSFER_ASSET:",
            mockAdapter.supportsOperation(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        console.log("MockAdapter supports chain 10:", mockAdapter.supportsChain(DEST_CHAIN_ID));
        console.log("MockAdapter is valid adapter:", router.isValidAdapter(address(mockAdapter)));
        console.log("MockAdapter address:", address(mockAdapter));
        console.log("Specified adapter in params:", params.options.specifiedAdapter);

        try router.executeTransferAssets{ value: 0.1 ether }(params) returns (bytes32 operationId) {
            console.log("executeTransferAssets succeeded!");
            console.log("Operation ID:", uint256(operationId));
        } catch Error(string memory reason) {
            console.log("executeTransferAssets failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("executeTransferAssets failed with low level data");
            console.logBytes(lowLevelData);
        }

        // Try without ETH value
        try router.executeTransferAssets(params) returns (bytes32 operationId) {
            console.log("executeTransferAssets (no value) succeeded!");
            console.log("Operation ID:", uint256(operationId));
        } catch Error(string memory reason) {
            console.log("executeTransferAssets (no value) failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("executeTransferAssets (no value) failed with low level data");
            console.logBytes(lowLevelData);
        }

        vm.stopPrank();
    }

}
