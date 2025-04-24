// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {BridgeQueue} from "../../src/router/BridgeQueue.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockBridgeRouter} from "../mocks/MockBridgeRouter.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

contract BridgeQueueTest is Test {
    // Contracts
    BridgeQueue internal queue;
    MockBridgeRouter internal router;
    ERC20Mock internal asset;
    ProtocolAccessManager internal accessManager;

    // Addresses
    address internal queueManager = makeAddr("queueManager");
    address internal originator = makeAddr("originator"); // Who the queueManager acts on behalf of
    address internal recipient = makeAddr("recipient");
    address internal keeper = makeAddr("keeper");
    address internal governor = makeAddr("governor"); // For admin functions
    address internal testAdmin = address(this); // Address deploying the test contract is admin
    address internal immutable MOCK_ADAPTER;

    // Constants
    uint16 internal constant DEST_CHAIN_ID = 10;
    uint256 internal constant TRANSFER_AMOUNT = 100 ether;
    uint256 internal constant ROUTER_FEE_MULTIPLIER = 200; // 200% -> base fee is half
    uint256 internal constant BASE_NATIVE_FEE = 0.1 ether; // Fee adapter needs
    uint256 internal constant TOTAL_NATIVE_FEE =
        (BASE_NATIVE_FEE * ROUTER_FEE_MULTIPLIER) / 100; // Fee user pays
    uint256 internal constant TOKEN_FEE = 1 ether; // Example token fee (not used in current queue logic)

    // Constructor to initialize immutable variables
    constructor() {
        MOCK_ADAPTER = makeAddr("mockAdapter");
    }

    function setUp() public {
        // Deploy Mocks & REAL Access Manager
        accessManager = new ProtocolAccessManager(testAdmin);
        router = new MockBridgeRouter();
        asset = new ERC20Mock();

        // Configure Access Manager
        vm.prank(testAdmin);
        accessManager.grantGovernorRole(governor);

        queue = new BridgeQueue(
            address(accessManager),
            address(router),
            queueManager
        );

        // Set up mock bridge router
        router.setBridgeQueueAddress(address(queue));

        asset.mint(queueManager, TRANSFER_AMOUNT * 10);
        vm.deal(queueManager, TOTAL_NATIVE_FEE * 10);

        vm.deal(governor, 1 ether);
    }

    // Helper to create default bridge options
    function _defaultOptions()
        internal
        pure
        returns (BridgeTypes.BridgeOptions memory)
    {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(0), // Use best adapter
                adapterParams: BridgeTypes.AdapterParams({
                    gasLimit: 200000,
                    msgValue: 0, // Not used directly here
                    calldataSize: 0, // Not used directly here
                    options: ""
                })
            });
    }

    // Helper to create queueId deterministically based on nonce
    function _expectedQueueId(uint256 nonce) internal view returns (bytes32) {
        return
            keccak256(abi.encodePacked(block.chainid, address(queue), nonce));
    }

    // Helper to get QueuedTransfer struct from public getter
    function _getQueuedTransfer(
        bytes32 queueId
    ) internal view returns (BridgeQueue.QueuedTransfer memory) {
        (
            uint16 destinationChainId,
            address asset_, // Use _ suffix to avoid shadowing
            uint256 amount,
            address recipient_, // Use _ suffix
            BridgeTypes.BridgeOptions memory options,
            address originator_, // Use _ suffix
            uint256 feePaid,
            bytes32 operationId
        ) = queue.queuedTransfers(queueId);

        // Reconstruct the struct in memory
        return
            BridgeQueue.QueuedTransfer({
                destinationChainId: destinationChainId,
                asset: asset_,
                amount: amount,
                recipient: recipient_,
                options: options, // This is already memory
                originator: originator_,
                feePaid: feePaid,
                operationId: operationId
            });
    }

    // Helper to get QueuedReadState struct from public getter
    function _getQueuedReadState(
        bytes32 queueId
    ) internal view returns (BridgeQueue.QueuedReadState memory) {
        (
            uint16 dstChainId,
            address dstContract,
            bytes4 selector,
            bytes memory readParams, // memory already
            BridgeTypes.BridgeOptions memory options, // memory already
            address originator_,
            uint256 feePaid,
            bytes32 operationId
        ) = queue.queuedReadStates(queueId);

        return
            BridgeQueue.QueuedReadState({
                dstChainId: dstChainId,
                dstContract: dstContract,
                selector: selector,
                readParams: readParams,
                options: options,
                originator: originator_,
                feePaid: feePaid,
                operationId: operationId
            });
    }

    // Helper to get QueuedMessage struct from public getter
    function _getQueuedMessage(
        bytes32 queueId
    ) internal view returns (BridgeQueue.QueuedMessage memory) {
        (
            uint16 destinationChainId,
            address recipient_,
            bytes memory message, // memory already
            BridgeTypes.BridgeOptions memory options, // memory already
            address originator_,
            uint256 feePaid,
            bytes32 operationId
        ) = queue.queuedMessages(queueId);

        return
            BridgeQueue.QueuedMessage({
                destinationChainId: destinationChainId,
                recipient: recipient_,
                message: message,
                options: options,
                originator: originator_,
                feePaid: feePaid,
                operationId: operationId
            });
    }

    // --- Test Queueing ---

    function test_QueueTransferAssets() public {
        // Arrange
        uint16 destChainId = DEST_CHAIN_ID;
        uint256 amount = TRANSFER_AMOUNT;
        BridgeTypes.BridgeOptions memory options = _defaultOptions();
        uint256 startBalanceManager = address(queueManager).balance;
        uint256 startBalanceQueue = address(queue).balance;
        uint256 startTokenBalanceManager = asset.balanceOf(queueManager);
        uint256 startTokenBalanceQueue = asset.balanceOf(address(queue));
        uint256 currentNonce = 0; // First operation
        bytes32 expectedQueueId = _expectedQueueId(currentNonce);

        // --- Mocking ---
        vm.expectCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                destChainId,
                address(asset),
                amount,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            )
        );

        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                destChainId,
                address(asset),
                amount,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            abi.encode(TOTAL_NATIVE_FEE, TOKEN_FEE, MOCK_ADAPTER) // Return total fee and adapter
        );

        // --- Approvals ---
        vm.startPrank(queueManager);
        asset.approve(address(queue), amount);

        // --- Act ---
        // Expect the event
        vm.expectEmit(true, true, true, true, address(queue));
        emit BridgeQueue.OperationQueued(
            expectedQueueId,
            BridgeTypes.OperationType.TRANSFER_ASSET,
            queueManager, // Originator is queueManager in this setup
            destChainId,
            TOTAL_NATIVE_FEE
        );

        // Call the function
        bytes32 queueId = queue.queueTransferAssets{value: TOTAL_NATIVE_FEE}(
            destChainId,
            address(asset),
            amount,
            recipient,
            options
        );
        vm.stopPrank();

        // --- Assert ---
        // ID
        assertEq(queueId, expectedQueueId, "Incorrect queueId");

        // State Storage - Use the helper function
        BridgeQueue.QueuedTransfer memory storedTransfer = _getQueuedTransfer(
            queueId
        );

        // Access fields from the memory struct
        assertEq(
            storedTransfer.destinationChainId,
            destChainId,
            "Stored destChainId mismatch"
        );
        assertEq(storedTransfer.asset, address(asset), "Stored asset mismatch");
        assertEq(storedTransfer.amount, amount, "Stored amount mismatch");
        assertEq(
            storedTransfer.recipient,
            recipient,
            "Stored recipient mismatch"
        );
        assertEq(
            storedTransfer.originator,
            queueManager,
            "Stored originator mismatch"
        );
        assertEq(
            storedTransfer.feePaid,
            TOTAL_NATIVE_FEE,
            "Stored feePaid mismatch"
        );
        assertEq(
            storedTransfer.operationId,
            bytes32(0),
            "Stored operationId should be zero"
        );
        // Compare options fields individually from the memory struct
        assertEq(
            storedTransfer.options.specifiedAdapter,
            options.specifiedAdapter,
            "Stored options.specifiedAdapter mismatch"
        );
        assertEq(
            storedTransfer.options.adapterParams.gasLimit,
            options.adapterParams.gasLimit,
            "Stored options.adapterParams.gasLimit mismatch"
        );
        assertEq(
            storedTransfer.options.adapterParams.calldataSize,
            options.adapterParams.calldataSize,
            "Stored options.adapterParams.calldataSize mismatch"
        );
        assertEq(
            storedTransfer.options.adapterParams.msgValue,
            options.adapterParams.msgValue,
            "Stored options.adapterParams.msgValue mismatch"
        );
        assertEq(
            keccak256(storedTransfer.options.adapterParams.options), // Hash bytes for comparison
            keccak256(options.adapterParams.options),
            "Stored options.adapterParams.options mismatch"
        );

        assertEq(
            uint8(queue.queueIdToOperationType(queueId)),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET),
            "Stored opType mismatch"
        );
        assertEq(
            uint8(queue.queueIdToStatus(queueId)),
            uint8(BridgeTypes.OperationStatus.QUEUED),
            "Stored status mismatch"
        );

        // Pending Queue List
        assertEq(
            queue.getPendingQueueCount(),
            1,
            "Pending queue count mismatch"
        );
        assertEq(
            queue.getPendingQueueIdAtIndex(0),
            queueId,
            "Pending queue ID mismatch"
        );

        // Balances
        assertEq(
            address(queueManager).balance,
            startBalanceManager - TOTAL_NATIVE_FEE,
            "Manager ETH balance mismatch"
        );
        assertEq(
            address(queue).balance,
            startBalanceQueue + TOTAL_NATIVE_FEE,
            "Queue ETH balance mismatch"
        );
        assertEq(
            asset.balanceOf(queueManager),
            startTokenBalanceManager - amount,
            "Manager token balance mismatch"
        );
        assertEq(
            asset.balanceOf(address(queue)),
            startTokenBalanceQueue + amount,
            "Queue token balance mismatch"
        );

        // Nonce incremented
        // Note: We can't directly check the private `queueNonce`, but the next call should use nonce 1.
    }

    function test_QueueReadState() public {
        // Arrange
        uint16 dstChainId = DEST_CHAIN_ID;
        address dstContract = makeAddr("destContract");
        bytes4 selector = bytes4(keccak256("someFunction(uint256)"));
        bytes memory readParams = abi.encode(uint256(123));
        BridgeTypes.BridgeOptions memory options = _defaultOptions();
        uint256 currentNonce = 0;
        bytes32 expectedQueueId = _expectedQueueId(currentNonce);

        // --- Mocking ---
        vm.expectCall(
            address(router),
            abi.encodeWithSelector( // Use selector directly
                    IBridgeRouter.quote.selector,
                    dstChainId,
                    address(0), // No asset for read
                    0, // No amount for read
                    options,
                    BridgeTypes.OperationType.READ_STATE
                )
        );
        vm.mockCall(
            address(router),
            abi.encodeWithSelector( // Use selector directly
                    IBridgeRouter.quote.selector,
                    dstChainId,
                    address(0), // No asset for read
                    0, // No amount for read
                    options,
                    BridgeTypes.OperationType.READ_STATE
                ),
            abi.encode(TOTAL_NATIVE_FEE, uint256(0), MOCK_ADAPTER) // No token fee, adapter returned
        );

        // --- Act ---
        vm.startPrank(queueManager);
        // Expect the event
        vm.expectEmit(true, true, true, true, address(queue));
        emit BridgeQueue.OperationQueued(
            expectedQueueId,
            BridgeTypes.OperationType.READ_STATE,
            queueManager, // Originator is queueManager
            dstChainId,
            TOTAL_NATIVE_FEE
        );
        bytes32 queueId = queue.queueReadState{value: TOTAL_NATIVE_FEE}(
            dstChainId,
            dstContract,
            selector,
            readParams,
            options
        );
        vm.stopPrank();

        // --- Assert ---
        assertEq(queueId, expectedQueueId, "Incorrect queueId");

        // State Storage - Use the helper function
        BridgeQueue.QueuedReadState memory storedRead = _getQueuedReadState(
            queueId
        );

        // Access fields from the memory struct
        assertEq(
            storedRead.dstChainId,
            dstChainId,
            "Stored dstChainId mismatch"
        );
        assertEq(
            storedRead.dstContract,
            dstContract,
            "Stored dstContract mismatch"
        );
        assertEq(storedRead.selector, selector, "Stored selector mismatch");
        assertEq(
            keccak256(storedRead.readParams),
            keccak256(readParams),
            "Stored readParams mismatch"
        ); // Hash bytes
        assertEq(
            storedRead.originator,
            queueManager,
            "Stored originator mismatch"
        );
        assertEq(
            storedRead.feePaid,
            TOTAL_NATIVE_FEE,
            "Stored feePaid mismatch"
        );
        assertEq(
            storedRead.operationId,
            bytes32(0),
            "Stored operationId mismatch"
        );
        // Compare options fields individually
        assertEq(
            storedRead.options.specifiedAdapter,
            options.specifiedAdapter,
            "Stored options.specifiedAdapter mismatch"
        );
        assertEq(
            storedRead.options.adapterParams.gasLimit,
            options.adapterParams.gasLimit,
            "Stored options.adapterParams.gasLimit mismatch"
        );
        // ... compare other adapterParams fields if necessary

        assertEq(
            uint8(queue.queueIdToOperationType(queueId)),
            uint8(BridgeTypes.OperationType.READ_STATE),
            "Stored opType mismatch"
        );
        assertEq(
            uint8(queue.queueIdToStatus(queueId)),
            uint8(BridgeTypes.OperationStatus.QUEUED),
            "Stored status mismatch"
        );
        // Check pending queue list
        assertEq(
            queue.getPendingQueueCount(),
            1,
            "Pending queue count mismatch"
        );
        assertEq(
            queue.getPendingQueueIdAtIndex(0),
            queueId,
            "Pending queue ID mismatch"
        );
    }

    function test_QueueSendMessage() public {
        // Arrange
        uint16 destChainId = DEST_CHAIN_ID;
        bytes memory message = abi.encode("hello world");
        BridgeTypes.BridgeOptions memory options = _defaultOptions();
        uint256 currentNonce = 0;
        bytes32 expectedQueueId = _expectedQueueId(currentNonce);

        // --- Mocking ---
        vm.expectCall(
            address(router),
            abi.encodeWithSelector( // Use selector directly
                    IBridgeRouter.quote.selector,
                    destChainId,
                    address(0), // No asset
                    0, // No amount
                    options,
                    BridgeTypes.OperationType.MESSAGE
                )
        );
        vm.mockCall(
            address(router),
            abi.encodeWithSelector( // Use selector directly
                    IBridgeRouter.quote.selector,
                    destChainId,
                    address(0),
                    0,
                    options,
                    BridgeTypes.OperationType.MESSAGE
                ),
            abi.encode(TOTAL_NATIVE_FEE, uint256(0), MOCK_ADAPTER) // No token fee
        );

        // --- Act ---
        vm.startPrank(queueManager);
        // Expect event
        vm.expectEmit(true, true, true, true, address(queue));
        emit BridgeQueue.OperationQueued(
            expectedQueueId,
            BridgeTypes.OperationType.MESSAGE,
            queueManager,
            destChainId,
            TOTAL_NATIVE_FEE
        );
        bytes32 queueId = queue.queueSendMessage{value: TOTAL_NATIVE_FEE}(
            destChainId,
            recipient,
            message,
            options
        );
        vm.stopPrank();

        // --- Assert ---
        assertEq(queueId, expectedQueueId, "Incorrect queueId");

        // State Storage - Fetch struct into memory variable
        BridgeQueue.QueuedMessage memory storedMessage = _getQueuedMessage(
            queueId
        );

        // Access fields from the memory struct
        assertEq(
            storedMessage.destinationChainId,
            destChainId,
            "Stored destChainId mismatch"
        );
        assertEq(
            storedMessage.recipient,
            recipient,
            "Stored recipient mismatch"
        );
        assertEq(
            keccak256(storedMessage.message),
            keccak256(message),
            "Stored message mismatch"
        ); // Hash bytes
        assertEq(
            storedMessage.originator,
            queueManager,
            "Stored originator mismatch"
        );
        assertEq(
            storedMessage.feePaid,
            TOTAL_NATIVE_FEE,
            "Stored feePaid mismatch"
        );
        assertEq(
            storedMessage.operationId,
            bytes32(0),
            "Stored operationId mismatch"
        );
        // Compare options fields individually
        assertEq(
            storedMessage.options.specifiedAdapter,
            options.specifiedAdapter,
            "Stored options.specifiedAdapter mismatch"
        );
        assertEq(
            storedMessage.options.adapterParams.gasLimit,
            options.adapterParams.gasLimit,
            "Stored options.adapterParams.gasLimit mismatch"
        );
        // ... compare other adapterParams fields if necessary

        assertEq(
            uint8(queue.queueIdToOperationType(queueId)),
            uint8(BridgeTypes.OperationType.MESSAGE),
            "Stored opType mismatch"
        );
        assertEq(
            uint8(queue.queueIdToStatus(queueId)),
            uint8(BridgeTypes.OperationStatus.QUEUED),
            "Stored status mismatch"
        );
        // Check pending queue list
        assertEq(
            queue.getPendingQueueCount(),
            1,
            "Pending queue count mismatch"
        );
        assertEq(
            queue.getPendingQueueIdAtIndex(0),
            queueId,
            "Pending queue ID mismatch"
        );
    }

    // --- Test Queue Failures ---

    function test_Fail_QueueTransfer_NotManager() public {
        // Arrange
        BridgeTypes.BridgeOptions memory options = _defaultOptions();

        // Act & Assert
        vm.expectRevert(BridgeQueue.CallerNotQueueManager.selector);
        vm.prank(originator); // Use a different address
        queue.queueTransferAssets{value: TOTAL_NATIVE_FEE}(
            DEST_CHAIN_ID,
            address(asset),
            TRANSFER_AMOUNT,
            recipient,
            options
        );
    }

    function test_Fail_QueueTransfer_InsufficientFee() public {
        // Arrange
        BridgeTypes.BridgeOptions memory options = _defaultOptions();
        uint256 insufficientFee = TOTAL_NATIVE_FEE - 1; // Send 1 wei less

        // Mock quote
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                DEST_CHAIN_ID,
                address(asset),
                TRANSFER_AMOUNT,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            abi.encode(TOTAL_NATIVE_FEE, TOKEN_FEE, MOCK_ADAPTER)
        );

        // Act & Assert
        vm.expectRevert(BridgeQueue.InsufficientFee.selector);
        vm.startPrank(queueManager);
        queue.queueTransferAssets{value: insufficientFee}(
            DEST_CHAIN_ID,
            address(asset),
            TRANSFER_AMOUNT,
            recipient,
            options
        );
        vm.stopPrank();
    }

    function test_Fail_QueueTransfer_InvalidParams_ZeroAmount() public {
        // Arrange
        BridgeTypes.BridgeOptions memory options = _defaultOptions();

        // Act & Assert
        vm.expectRevert(BridgeQueue.InvalidParams.selector);
        vm.startPrank(queueManager);
        queue.queueTransferAssets{value: TOTAL_NATIVE_FEE}(
            DEST_CHAIN_ID,
            address(asset),
            0, // Zero amount
            recipient,
            options
        );
        vm.stopPrank();
    }

    function test_Fail_QueueTransfer_InvalidParams_ZeroRecipient() public {
        // Arrange
        BridgeTypes.BridgeOptions memory options = _defaultOptions();

        // Act & Assert
        vm.expectRevert(BridgeQueue.InvalidParams.selector);
        vm.startPrank(queueManager);
        queue.queueTransferAssets{value: TOTAL_NATIVE_FEE}(
            DEST_CHAIN_ID,
            address(asset),
            TRANSFER_AMOUNT,
            address(0), // Zero recipient
            options
        );
        vm.stopPrank();
    }

    // --- Test Execution ---
    function test_ExecuteQueuedOperation_Transfer() public {
        // Arrange
        uint16 destChainId = DEST_CHAIN_ID;
        uint256 amount = TRANSFER_AMOUNT;
        BridgeTypes.BridgeOptions memory options = _defaultOptions();
        vm.startPrank(queueManager);
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                destChainId,
                address(asset),
                amount,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            abi.encode(TOTAL_NATIVE_FEE, TOKEN_FEE, MOCK_ADAPTER)
        );
        asset.approve(address(queue), amount);
        bytes32 queueId = queue.queueTransferAssets{value: TOTAL_NATIVE_FEE}(
            destChainId,
            address(asset),
            amount,
            recipient,
            options
        );
        vm.stopPrank();

        // Prepare expected parameters for the router call (using the struct)
        BridgeTypes.ExecuteTransferParams
            memory expectedRouterParams = BridgeTypes.ExecuteTransferParams({
                destinationChainId: destChainId,
                asset: address(asset),
                amount: amount,
                recipient: recipient,
                originator: queueManager, // Originator was queueManager
                options: options
            });
        bytes32 expectedOperationId = keccak256(
            // Match the MockBridgeRouter's operationId generation for the first call (nonce = 0)
            abi.encodePacked("transfer", uint256(0))
        );

        // --- Mocking Router Execution ---
        // Mock the quote call that happens *inside* executeQueuedOperation
        vm.mockCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                destChainId,
                address(asset),
                amount,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            abi.encode(BASE_NATIVE_FEE, TOKEN_FEE, MOCK_ADAPTER) // Return BASE fee now
        );
        // Mock the actual executeTransferAssets call on the router
        vm.expectCall(
            address(router),
            TOTAL_NATIVE_FEE, // Expect the base fee to be sent
            abi.encodeWithSelector(
                IBridgeRouter.executeTransferAssets.selector,
                expectedRouterParams
            ) // Expect struct param
        );
        vm.mockCall(
            address(router),
            TOTAL_NATIVE_FEE,
            abi.encodeWithSelector(
                IBridgeRouter.executeTransferAssets.selector,
                expectedRouterParams
            ),
            abi.encode(expectedOperationId) // Return operationId
        );

        // --- Act ---
        vm.startPrank(keeper); // Keeper executes
        // Expect event
        vm.expectEmit(true, true, true, true, address(queue));
        emit BridgeQueue.OperationExecuted(
            queueId,
            expectedOperationId,
            keeper
        );

        bytes32 actualOperationId = queue.executeQueuedOperation(queueId);
        vm.stopPrank();

        // --- Assert ---
        assertEq(
            actualOperationId,
            expectedOperationId,
            "Returned operationId mismatch"
        );

        // Check queue state updated
        assertEq(
            uint8(queue.queueIdToStatus(queueId)),
            uint8(BridgeTypes.OperationStatus.PENDING),
            "Queue status should be PENDING"
        );
        assertEq(
            queue.operationIdToQueueId(expectedOperationId),
            queueId,
            "operationId mapping incorrect"
        );
        assertEq(
            queue.getPendingQueueCount(),
            0,
            "Pending queue should be empty"
        ); // Item removed

        // Verify operationId stored in the queued item using the helper
        BridgeQueue.QueuedTransfer memory storedTransfer = _getQueuedTransfer(
            queueId
        );

        assertEq(
            storedTransfer.operationId,
            expectedOperationId,
            "Operation ID not stored in queued item"
        );
    }

    // Add similar execution tests for ReadState and SendMessage, updating mocks for struct params

    // --- Test Execution Failures ---
    // ...

    // --- Test Dequeueing ---
    // ...
}
