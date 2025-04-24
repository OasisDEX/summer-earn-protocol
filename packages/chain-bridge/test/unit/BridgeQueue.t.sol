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

    // Constants
    uint16 internal constant DEST_CHAIN_ID = 10;
    uint256 internal constant TRANSFER_AMOUNT = 100 ether;
    uint256 internal constant ROUTER_FEE_MULTIPLIER = 200; // 200% -> base fee is half
    uint256 internal constant BASE_NATIVE_FEE = 0.1 ether; // Fee adapter needs
    uint256 internal constant TOTAL_NATIVE_FEE =
        (BASE_NATIVE_FEE * ROUTER_FEE_MULTIPLIER) / 100; // Fee user pays
    uint256 internal constant TOKEN_FEE = 1 ether; // Example token fee (not used in current queue logic)
    address internal constant MOCK_ADAPTER = makeAddr("mockAdapter");

    function setUp() public {
        // Deploy Mocks & REAL Access Manager
        accessManager = new ProtocolAccessManager(testAdmin);
        router = new MockBridgeRouter();
        asset = new ERC20Mock();

        // Configure Access Manager
        bytes32 governorRole = accessManager.GOVERNOR_ROLE();

        vm.prank(testAdmin);
        accessManager.grantRole(governorRole, governor);

        queue = new BridgeQueue(
            address(accessManager),
            address(router),
            queueManager
        );

        vm.prank(testAdmin);
        accessManager.grantRole(governorRole, address(queue));

        router.setFeeMultiplier(ROUTER_FEE_MULTIPLIER);

        asset.mint(queueManager, TRANSFER_AMOUNT * 10);
        vm.deal(queueManager, TOTAL_NATIVE_FEE * 10);

        vm.deal(governor, 1 ether);
    }

    // Helper to create default bridge options
    function _defaultOptions()
        internal
        view
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
        // Mock the quote call on the router
        vm.expectCall(
            address(router),
            abi.encodeWithSelector(
                IBridgeRouter.quote.selector,
                destChainId,
                address(asset),
                amount,
                options,
                BridgeTypes.OperationType.TRANSFER_ASSET
            ),
            MockBridgeRouter.QUOTE_GAS // Provide gas estimate if needed by mock
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

        // State Storage
        BridgeQueue.QueuedTransfer memory queuedData = queue.queuedTransfers(
            queueId
        );
        assertEq(
            queuedData.destinationChainId,
            destChainId,
            "Stored destChainId mismatch"
        );
        assertEq(queuedData.asset, address(asset), "Stored asset mismatch");
        assertEq(queuedData.amount, amount, "Stored amount mismatch");
        assertEq(queuedData.recipient, recipient, "Stored recipient mismatch");
        assertEq(
            queuedData.originator,
            queueManager,
            "Stored originator mismatch"
        );
        assertEq(
            queuedData.feePaid,
            TOTAL_NATIVE_FEE,
            "Stored feePaid mismatch"
        );
        assertEq(
            queuedData.operationId,
            bytes32(0),
            "Stored operationId should be zero"
        );
        // assertEq(keccak256(abi.encode(queuedData.options)), keccak256(abi.encode(options)), "Stored options mismatch"); // Deep struct compare tricky

        assertEq(
            queue.queueIdToOperationType(queueId),
            BridgeTypes.OperationType.TRANSFER_ASSET,
            "Stored opType mismatch"
        );
        assertEq(
            queue.queueIdToStatus(queueId),
            BridgeTypes.OperationStatus.QUEUED,
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

    // --- TODO: Add tests for ---
    // test_QueueReadState
    // test_QueueSendMessage
    // test_ExecuteQueuedTransfer
    // test_ExecuteQueuedReadState
    // test_ExecuteQueuedMessage
    // test_Execute_Fail_NotQueued
    // test_Execute_Fail_RouterReverts
    // test_DequeueOperation (including refunds)
    // test_AdminFunctions (setters, withdrawals)
    // test_GetOperationStatus (checking router status after execution)
}
