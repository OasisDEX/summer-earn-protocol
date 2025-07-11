// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {ICrossChainStateReadReceiver} from "../../src/interfaces/ICrossChainStateReadReceiver.sol";

contract BridgeRouterReadStateTest is Test {
    BridgeRouterTestHelper public router;
    MockAdapter public mockAdapter;
    MockAdapter public mockAdapter2;
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;
    MockCrossChainReceiver public mockReceiver;

    address public governor = address(0x1);
    address public user = address(0x2);
    address public keeper = address(0x3);
    // todo: authorize the caller when method available ( uthorized to call bridge router)
    address public authorizedCaller = address(0x5);

    // Constants for testing
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism
    uint256 public constant TRANSFER_AMOUNT = 1000e18;

    uint8 constant OPTION_TYPE_EXECUTOR = 1;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 constant OPTION_TYPE_EXECUTOR_LZ_READ = 5;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);
        mockReceiver = new MockCrossChainReceiver();

        vm.startPrank(governor);

        // Deploy BridgeRouterTestHelper, linking it to the queue
        router = new BridgeRouterTestHelper(address(accessManager));

        mockAdapter = new MockAdapter(address(router));
        mockAdapter2 = new MockAdapter(address(router));
        token = new ERC20Mock();

        // Setup mock adapter
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);

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
        address targetContract = address(token); // Use a valid address for setup
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);

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
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });

        // Quote fee FOR EXECUTION
        (uint256 fee, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            targetContract, // Use target contract in quote
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        // Verify the specified adapter matches what we provided
        assertEq(specifiedAdapter, address(mockAdapter));

        // Use specified adapter in options for queueing
        options.specifiedAdapter = specifiedAdapter;

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        bytes32 operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                destinationContract: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: address(mockReceiver),
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();

        // Verify queue status updated post-execution
        assertEq(
            uint256(router.getOperationStatus(operationId)),
            uint256(BridgeTypes.OperationStatus.SENT) // Should be SENT as it's sent to adapter
        );

        // todo: expect calls to lz endpoint to be made
    }

    function testDeliverReadResponse() public {
        bytes32 operationId; // Declare operationId outside prank scope
        address targetContract = address(0x123);
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);

        // mockReceiver (queueManager) queues the operation (NO VALUE)
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

        // Quote fee FOR EXECUTION
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            targetContract,
            0,
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                destinationContract: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: address(mockReceiver),
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();

        // Set up the operation mappings using the test helper
        vm.prank(address(router));
        router.setOperationToAdapter(operationId, address(mockAdapter));
        router.setReadRequestOriginator(operationId, address(mockReceiver));
        // Set initial status to SENT
        router.setOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );

        // Now deliver the response from the adapter
        vm.prank(address(mockAdapter));
        // Expect the call to the receiver with correct parameter order
        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(
                ICrossChainStateReadReceiver.receiveStateRead.selector,
                abi.encode(uint256(100)), // resultData
                address(mockReceiver), // originator
                operationId, // operationId
                DEST_CHAIN_ID // sourceChainId
            )
        );
        router.deliverReadResponse(
            operationId,
            DEST_CHAIN_ID,
            abi.encode(uint256(100))
        );

        // Verify that the mockReceiver received the data
        assertEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
        // Originator of the read request was mockReceiver
        assertEq(mockReceiver.lastSender(), address(mockReceiver));
        assertEq(mockReceiver.lastSourceChainId(), DEST_CHAIN_ID);
    }

    function testDeliverReadResponseUnauthorized() public {
        bytes32 operationId; // Declare operationId
        address targetContract = address(0x123);
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);
        BridgeTypes.BridgeOptions memory options; // Declare options outside prank

        // mockReceiver (queueManager) queues the operation (NO VALUE)
        vm.startPrank(address(mockReceiver));
        // Create bridge options inside prank
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });
        options = BridgeTypes.BridgeOptions({ // Initialize options here
                specifiedAdapter: address(mockAdapter), // Specify adapter
                adapterParams: adapterParams
            });

        // Quote fee FOR EXECUTION
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            targetContract,
            0,
            options, // Use options
            BridgeTypes.OperationType.READ_STATE
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                destinationContract: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: address(mockReceiver),
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();

        // Test case 1: Non-adapter trying to deliver response
        vm.prank(address(0x999)); // Random non-adapter address
        vm.expectRevert(IBridgeRouter.UnknownAdapter.selector);
        router.deliverReadResponse(
            operationId,
            DEST_CHAIN_ID,
            abi.encode(uint256(100))
        );

        // Register second adapter
        vm.prank(governor);
        router.registerAdapter(address(mockAdapter2));

        // Test case 2: Different adapter trying to deliver response
        vm.prank(address(mockAdapter2));
        vm.expectRevert(IBridgeRouter.Unauthorized.selector);
        router.deliverReadResponse(
            operationId,
            DEST_CHAIN_ID,
            abi.encode(uint256(100))
        );
    }

    function testDeliverReadResponseReceiverRejects() public {
        bytes32 operationId; // Declare operationId
        address targetContract = address(0x123);
        bytes4 targetSelector = bytes4(keccak256("getBalance(address)"));
        bytes memory targetCalldata = abi.encode(user);
        BridgeTypes.BridgeOptions memory options; // Declare options outside prank

        // Configure the receiver to reject the call
        mockReceiver.setReceiveSuccess(false);

        // mockReceiver (queueManager) queues the operation (NO VALUE)
        vm.startPrank(address(mockReceiver));
        // Create bridge options inside prank
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 100,
                msgValue: 0,
                options: ""
            });
        options = BridgeTypes.BridgeOptions({ // Initialize options here
                specifiedAdapter: address(mockAdapter), // Specify adapter
                adapterParams: adapterParams
            });

        // Quote fee FOR EXECUTION
        (uint256 fee, , ) = router.quote(
            DEST_CHAIN_ID,
            targetContract,
            0,
            options, // Use options
            BridgeTypes.OperationType.READ_STATE
        );

        vm.stopPrank(); // mockReceiver stops queueing

        // Keeper executes (PAYS FEE)
        vm.startPrank(keeper);

        operationId = router.executeReadState{value: fee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                destinationContract: targetContract,
                selector: targetSelector,
                readParams: targetCalldata,
                originator: address(mockReceiver),
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();

        // Set up the operation mappings using the test helper
        vm.prank(address(router));
        router.setOperationToAdapter(operationId, address(mockAdapter));
        router.setReadRequestOriginator(operationId, address(mockReceiver));
        // Set initial status to SENT
        router.setOperationStatus(
            operationId,
            BridgeTypes.OperationStatus.SENT
        );

        // Attempt to deliver the response
        vm.prank(address(mockAdapter));
        // Expect the call to the router's deliver function
        vm.expectCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.deliverReadResponse.selector,
                operationId,
                DEST_CHAIN_ID,
                abi.encode(uint256(100))
            )
        );
        // Expect the call to the receiver, which will revert
        vm.expectCall(
            address(mockReceiver),
            abi.encodeWithSelector(
                ICrossChainStateReadReceiver.receiveStateRead.selector,
                abi.encode(uint256(100)), // resultData
                address(mockReceiver), // originator
                operationId, // operationId
                DEST_CHAIN_ID // sourceChainId
            )
            // Do not mock a return, let it revert
        );

        router.deliverReadResponse(
            operationId,
            DEST_CHAIN_ID,
            abi.encode(uint256(100))
        );

        // Verify status is FAILED (if checking router state)
        // assertEq(
        //     uint256(router.operationStatuses(operationId)),
        //     uint256(BridgeTypes.OperationStatus.FAILED)
        // );
        // Optionally check that mockReceiver's state wasn't updated due to rejection
        assertNotEq(uint256(bytes32(mockReceiver.lastReceivedData())), 100);
    }
}
