// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {DeploymentController} from "@summerfi/access-contracts/contracts/DeploymentController.sol";

contract BridgeRouterAdaptersTest is Test {
    BridgeRouter public router;
    BridgeQueue public bridgeQueue;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x2);
    address public keeper = address(0x3);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);

        vm.startPrank(governor);

        // Deploy BridgeQueue first
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Router address set later
            user // queueManager
        );

        // Deploy router, linking it to the queue
        router = new BridgeRouter(address(accessManager), address(bridgeQueue));

        // Set the router address in the queue
        bridgeQueue.setBridgeRouter(address(router));

        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(governor, 10000e18);
        token.mint(user, 10000e18);

        // Fund keeper for execution - give enough for the base fee (0.1 ETH)
        vm.deal(keeper, 1 ether);

        vm.stopPrank();
    }

    // ---- ADAPTER MANAGEMENT TESTS ----

    function testRegisterAdapter() public {
        vm.startPrank(governor);

        // Register second adapter
        assertFalse(router.isValidAdapter(address(mockAdapter2)));
        router.registerAdapter(address(mockAdapter2));
        assertTrue(router.isValidAdapter(address(mockAdapter2)));

        vm.stopPrank();
    }

    function testRegisterAdapterUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-governor tries to register adapter (in governance mode)
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.registerAdapter(address(mockAdapter2));

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

        // Should revert when non-governor tries to remove adapter (in governance mode)
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
        router.removeAdapter(address(mockAdapter2));

        vm.stopPrank();
    }

    function testGetAdapters() public {
        vm.startPrank(governor);

        // Register second adapter
        router.registerAdapter(address(mockAdapter2));

        // Get adapters
        address[] memory adapterList = router.getAdapters();
        assertEq(adapterList.length, 2);
        assertEq(adapterList[0], address(mockAdapter));
        assertEq(adapterList[1], address(mockAdapter2));

        vm.stopPrank();
    }

    // ---- ADAPTER SPECIFICATION TESTS ----

    function testSpecifiedAdapter() public {
        vm.startPrank(governor);
        // Configure mockAdapter2 to support the destination chain and asset
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);

        // Register second adapter
        router.registerAdapter(address(mockAdapter2));
        vm.stopPrank();

        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options with specified adapter
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter2),
            adapterParams: adapterParams
        });

        // Get the required fee first (using router.quote) FOR EXECUTION
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Queue the transfer via BridgeQueue (NO VALUE)
        bytes32 queueId = bridgeQueue.queueTransferAssets(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user
        );

        vm.stopPrank(); // User stops queueing

        // Verify queue status
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        // Execute the queued operation (can be keeper or anyone) (PAYS FEE)
        vm.startPrank(keeper);
        // Mock the quote and execute calls happening during execution
        vm.expectCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(token),
                TRANSFER_AMOUNT,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            )
        );
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(token),
                TRANSFER_AMOUNT,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            abi.encode(nativeFee, uint256(0), address(mockAdapter2)) // Mock return for execution quote, specifying adapter 2
        );
        vm.expectCall(
            address(router),
            nativeFee, // Expect msg.value to be the fee
            abi.encodeWithSelector(IBridgeRouter.executeTransferAssets.selector) // Simplified check
        );
        bytes32 expectedOperationId = keccak256(
            abi.encodePacked("mockSpecifiedAdapterOpId", queueId)
        );
        vm.mockCall(
            address(router),
            nativeFee,
            abi.encodeWithSelector(
                IBridgeRouter.executeTransferAssets.selector
            ), // Need exact match if testing params
            abi.encode(expectedOperationId)
        );

        bytes32 operationId = bridgeQueue.executeQueuedOperation{
            value: nativeFee
        }(queueId, options);
        vm.stopPrank();

        // Verify queue status updated post-execution
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.SENT) // Should be SENT as it's sent to adapter
        );
        // Verify queue maps operationId
        assertEq(bridgeQueue.operationIdToQueueId(operationId), queueId);
        assertEq(operationId, expectedOperationId, "Operation ID mismatch");

        // Verify the specified adapter was used (if checking router state)
        // assertEq(router.operationToAdapter(operationId), address(mockAdapter2));
        // Verify router status (if checking router state)
        // assertEq(
        //     uint256(router.getOperationStatus(operationId)),
        //     uint256(BridgeTypes.OperationStatus.PENDING)
        // );
    }

    function testInvalidSpecifiedAdapter() public {
        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options with invalid adapter
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0x123), // Unregistered adapter
            adapterParams: adapterParams
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
        mockAdapter2.setSupportedChain(DEST_CHAIN_ID, true);
        router.registerAdapter(address(mockAdapter2));

        // Create an adapter that doesn't support the chain
        MockAdapter unsupportedChainAdapter = new MockAdapter(address(router));
        unsupportedChainAdapter.setSupportedChain(DEST_CHAIN_ID, false);
        router.registerAdapter(address(unsupportedChainAdapter));

        vm.stopPrank();

        // Create adapter params for testing
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 0,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        // Test 1: Valid adapter that supports everything
        BridgeTypes.BridgeOptions memory validOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                adapterParams: adapterParams
            });

        (, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            validOptions,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        assertEq(
            specifiedAdapter,
            address(mockAdapter),
            "Should return the specified valid adapter"
        );

        // Test 2: Adapter that doesn't support the chain - should fail at estimateFee level
        BridgeTypes.BridgeOptions memory invalidChainOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(unsupportedChainAdapter),
                adapterParams: adapterParams
            });

        vm.expectRevert(); // Will revert with UnsupportedChain from estimateFee
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            invalidChainOptions,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Test 3: Unregistered adapter
        BridgeTypes.BridgeOptions memory unregisteredOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(0x999),
                adapterParams: adapterParams
            });

        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            unregisteredOptions,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Test 4: No adapter specified
        BridgeTypes.BridgeOptions memory noAdapterOptions = BridgeTypes
            .BridgeOptions({
                specifiedAdapter: address(0),
                adapterParams: adapterParams
            });

        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            noAdapterOptions,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        // Test 5: Valid adapter with different token (MockAdapter supports any token)
        ERC20Mock newToken = new ERC20Mock();
        (, , address specifiedAdapterForNewToken) = router.quote(
            DEST_CHAIN_ID,
            address(newToken),
            TRANSFER_AMOUNT,
            validOptions,
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
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
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
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // No adapter specified
            adapterParams: adapterParams
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
