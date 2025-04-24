// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";

contract BridgeRouterReadStateTest is Test {
    BridgeRouterTestHelper public router;
    BridgeQueue public bridgeQueue;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;
    MockCrossChainReceiver public mockReceiver;

    address public governor = address(0x1);
    address public user = address(0x2);
    address public keeper = address(0x3);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);
        mockReceiver = new MockCrossChainReceiver();

        // Deploy BridgeQueue first, making mockReceiver the queue manager
        bridgeQueue = new BridgeQueue(
            address(accessManager),
            address(0), // Router address set later
            address(mockReceiver) // queueManager is mockReceiver
        );

        vm.startPrank(governor);

        // Deploy BridgeRouterTestHelper, linking it to the queue
        router = new BridgeRouterTestHelper(
            address(accessManager),
            address(bridgeQueue), // Link to queue
            new uint16[](0),
            new address[](0)
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

        // Mint tokens for user (if needed elsewhere)
        token.mint(user, 10000e18);
        // Fund mockReceiver (queue manager) and keeper
        vm.deal(address(mockReceiver), 10 ether);
        vm.deal(keeper, 1 ether);

        vm.stopPrank();
    }

    // ---- READ STATE TESTS ----

    function testReadState() public {
        // mockReceiver (queueManager) initiates
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0), // Auto-select
            adapterParams: adapterParams
        });

        // Quote fee
        (uint256 fee, , address selectedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token), // Using token here, adjust if needed
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Use selected adapter in options for queueing
        options.specifiedAdapter = selectedAdapter;

        // Queue read state
        bytes32 queueId = bridgeQueue.queueReadState{value: fee}(
            DEST_CHAIN_ID,
            address(token), // Target contract on dest chain
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user), // Calldata for target contract
            options
        );

        // Verify queue status
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.QUEUED)
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes
        vm.startPrank(keeper);
        bytes32 operationId = bridgeQueue.executeQueuedOperation(queueId);
        vm.stopPrank();

        // Verify queue status updated post-execution
        assertEq(
            uint256(bridgeQueue.queueIdToStatus(queueId)),
            uint256(BridgeTypes.OperationStatus.PENDING) // Should be pending as it's sent to adapter
        );
        // Verify queue maps operationId
        assertEq(bridgeQueue.operationIdToQueueId(operationId), queueId);

        // Verify request was initiated in router
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );
        assertEq(router.operationToAdapter(operationId), selectedAdapter); // Check selected adapter
        // Verify originator was stored correctly (should be mockReceiver)
        assertEq(
            router.readRequestToOriginator(operationId),
            address(mockReceiver)
        );
    }

    function testDeliverReadResponse() public {
        bytes32 operationId; // Declare operationId outside prank scope

        // mockReceiver (queueManager) queues the operation
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Specify adapter
            adapterParams: adapterParams
        });

        // Quote fee
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0x123), // Target contract address
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Queue read state
        bytes32 queueId = bridgeQueue.queueReadState{value: fee}(
            DEST_CHAIN_ID,
            address(0x123), // Target contract address
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user), // Calldata
            options
        );
        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes
        vm.startPrank(keeper);
        operationId = bridgeQueue.executeQueuedOperation(queueId); // Assign operationId
        vm.stopPrank();

        // Check router state before delivery
        assertEq(router.operationToAdapter(operationId), address(mockAdapter));
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.PENDING)
        );

        // Now deliver the response from the adapter
        vm.prank(address(mockAdapter));
        router.deliverReadResponse(operationId, abi.encode(uint256(100)));

        // Verify response was COMPLETED
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.COMPLETED)
        );

        // Verify that the mockReceiver received the data
        assertEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
        // Originator of the read request was mockReceiver
        assertEq(mockReceiver.lastSender(), address(mockReceiver));
        assertEq(mockReceiver.lastMessageId(), operationId);
    }

    function testDeliverReadResponseUnauthorized() public {
        bytes32 operationId; // Declare operationId

        // mockReceiver (queueManager) queues the operation
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Specify adapter
            adapterParams: adapterParams
        });

        // Quote fee
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0x123), // Target contract address
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Queue read state
        bytes32 queueId = bridgeQueue.queueReadState{value: fee}(
            DEST_CHAIN_ID,
            address(0x123), // Target contract address
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user), // Calldata
            options
        );
        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes
        vm.startPrank(keeper);
        operationId = bridgeQueue.executeQueuedOperation(queueId); // Assign operationId
        vm.stopPrank();

        // Should revert when non-adapter tries to deliver response
        vm.prank(address(0x999)); // Random non-adapter address
        // The adapter check now likely happens against operationToAdapter mapping
        vm.expectRevert(IBridgeRouter.Unauthorized.selector); // Expecting Unauthorized
        router.deliverReadResponse(operationId, abi.encode(uint256(100)));

        // Register second adapter
        vm.prank(governor);
        router.registerAdapter(address(mockAdapter2));

        // Should revert when wrong adapter tries to deliver response
        vm.prank(address(mockAdapter2));
        vm.expectRevert(IBridgeRouter.Unauthorized.selector);
        router.deliverReadResponse(operationId, abi.encode(uint256(100)));
    }

    function testDeliverReadResponseReceiverRejects() public {
        bytes32 operationId; // Declare operationId

        // Configure the receiver to reject the call
        mockReceiver.setReceiveSuccess(false);

        // mockReceiver (queueManager) queues the operation
        vm.startPrank(address(mockReceiver));

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Specify adapter
            adapterParams: adapterParams
        });

        // Quote fee
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0x123), // Target contract address
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Queue read state
        bytes32 queueId = bridgeQueue.queueReadState{value: fee}(
            DEST_CHAIN_ID,
            address(0x123), // Target contract address
            bytes4(keccak256("getBalance(address)")),
            abi.encode(user), // Calldata
            options
        );
        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes
        vm.startPrank(keeper);
        operationId = bridgeQueue.executeQueuedOperation(queueId); // Assign operationId
        vm.stopPrank();

        // Attempt to deliver the response
        // The router should catch the revert from the receiver and mark status as FAILED
        vm.prank(address(mockAdapter));
        router.deliverReadResponse(operationId, abi.encode(uint256(100)));

        // Verify status is FAILED
        assertEq(
            uint256(router.operationStatuses(operationId)),
            uint256(BridgeTypes.OperationStatus.FAILED)
        );
        // Optionally check that mockReceiver's state wasn't updated due to rejection
        assertNotEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
    }
}
