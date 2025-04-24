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

contract BridgeRouterTransferTest is Test {
    BridgeRouter public router;
    BridgeQueue public bridgeQueue;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public user = address(0x3);
    address public keeper = address(0x4);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    // Add these constants to each test file
    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);

        // Deploy BridgeQueue first
        // Make the user the queue manager
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Router address set later
            user // queueManager
        );

        vm.startPrank(governor);

        // Deploy router, linking it to the queue
        router = new BridgeRouter(
            address(accessManager),
            address(bridgeQueue), // Link to queue
            new uint16[](0), // Empty chainIds array
            new address[](0) // Empty routerAddresses array
        );

        // Set the router address in the queue
        bridgeQueue.setBridgeRouter(address(router));

        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapter.setSupportedAsset(DEST_CHAIN_ID, address(token), true);

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Mint tokens for testing
        token.mint(user, 10000e18);

        // Fund keeper for execution
        vm.deal(keeper, 1 ether);

        vm.stopPrank();
    }

    // ---- TRANSFER ASSET TESTS ----

    function testSend() public {
        // User initiates
        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Get a quote first to determine the required fee
        (uint256 nativeFee, , address selectedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        vm.deal(user, nativeFee); // Ensure user has fee amount

        // Ensure selected adapter is used if auto-selecting
        options.specifiedAdapter = selectedAdapter;

        // Queue the transfer via BridgeQueue
        bytes32 queueId = bridgeQueue.queueTransferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user, // recipient
            options
        );

        // Verify queue status
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        vm.stopPrank(); // User stops queueing

        // Keeper executes
        vm.startPrank(keeper);
        bytes32 operationId = bridgeQueue.executeQueuedOperation(queueId);
        vm.stopPrank();

        // Verify queue status updated post-execution
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );
        // Verify queue maps operationId
        assertEq(bridgeQueue.operationIdToQueueId(operationId), queueId);

        // Verify transfer was initiated in router
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );
        assertEq(router.operationToAdapter(operationId), selectedAdapter); // Check correct adapter used
    }

    function testSendInvalidParams() public {
        // User initiates
        vm.startPrank(user);

        // Approve tokens for the bridge queue
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Specify adapter
            adapterParams: adapterParams
        });

        // Get fee quote for valid amount first
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT, // Use valid amount for quote
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        vm.deal(user, nativeFee * 2); // Give enough ETH for potentially two ops

        // Queue transfer with zero amount - should succeed
        bytes32 queueIdZeroAmount = bridgeQueue.queueTransferAssets{
            value: nativeFee
        }(
            DEST_CHAIN_ID,
            address(token),
            0, // Zero amount
            user,
            options
        );

        // Queue transfer with zero recipient - should succeed
        bytes32 queueIdZeroRecipient = bridgeQueue.queueTransferAssets{
            value: nativeFee
        }(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            address(0), // Zero recipient
            options
        );

        vm.stopPrank(); // User stops queueing

        // Keeper attempts execution
        vm.startPrank(keeper);

        // Execution should revert with InvalidParams for zero amount
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        bridgeQueue.executeQueuedOperation(queueIdZeroAmount);

        // Execution should revert with InvalidParams for zero recipient
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        bridgeQueue.executeQueuedOperation(queueIdZeroRecipient);

        vm.stopPrank();
    }

    function testSendNoSuitableAdapter() public {
        vm.startPrank(user);

        // Approve tokens for the bridge queue (though it won't get that far)
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Quoting for an unsupported destination chain should revert directly
        vm.expectRevert(IBridgeRouter.NoSuitableAdapter.selector);
        router.quote(
            999, // Unsupported chain ID
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );

        vm.stopPrank();
    }

    function testUpdateTransferStatus() public {
        bytes32 operationId; // Declare operationId

        // User queues
        vm.startPrank(user);
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            adapterParams: adapterParams
        });
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        vm.deal(user, nativeFee);
        bytes32 queueId = bridgeQueue.queueTransferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );
        vm.stopPrank();

        // Keeper executes
        vm.startPrank(keeper);
        operationId = bridgeQueue.executeQueuedOperation(queueId);
        vm.stopPrank();

        // Update status from adapter
        vm.prank(address(mockAdapter));
        router.updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );

        // Verify status was updated in router
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.DELIVERED)
        );
    }

    function testUpdateTransferStatusUnauthorized() public {
        bytes32 operationId; // Declare operationId

        // User queues
        vm.startPrank(user);
        token.approve(address(bridgeQueue), TRANSFER_AMOUNT);
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            adapterParams: adapterParams
        });
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        vm.deal(user, nativeFee);
        bytes32 queueId = bridgeQueue.queueTransferAssets{value: nativeFee}(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            user,
            options
        );
        vm.stopPrank();

        // Keeper executes
        vm.startPrank(keeper);
        operationId = bridgeQueue.executeQueuedOperation(queueId);
        vm.stopPrank();

        // Should revert when non-adapter tries to update status
        vm.prank(user); // Use user address (or any other non-adapter)
        // Check is now against operationToAdapter mapping
        vm.expectRevert(IBridgeRouter.Unauthorized.selector);
        router.updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );

        // Register second adapter
        vm.prank(governor);
        router.registerAdapter(address(mockAdapter2));

        // Should revert when wrong adapter tries to deliver response
        vm.prank(address(mockAdapter2));
        vm.expectRevert(IBridgeRouter.Unauthorized.selector);
        router.updateOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );
    }
}
