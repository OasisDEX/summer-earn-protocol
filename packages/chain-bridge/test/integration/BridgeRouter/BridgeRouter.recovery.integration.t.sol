// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {BridgeRouter} from "../../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../../src/libraries/BridgeTypes.sol";

import {CrossChainRegistryOld} from "../../../src/contracts/CrossChainRegistryOld.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {MockAdapter} from "../../mocks/MockAdapter.sol";
import {MockCrossChainReceiver} from "../../mocks/MockCrossChainReceiver.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract BridgeRouterRecoveryIntegrationTest is Test {
    BridgeRouter public router;
    ProtocolAccessManager public accessManager;
    CrossChainRegistryOld public registry;

    MockAdapter public mockAdapter; // current chain adapter (registered)
    MockAdapter public mockAdapterDest; // remote adapter (peer)
    MockAdapter public mockAdapterSource; // source chain adapter (peer)
    MockAdapter public mockAdapterNoPeer; // registered adapter without SOURCE->CURRENT peer mapping
    MockCrossChainReceiver public mockReceiver;
    ERC20Mock public token;

    /// forge-lint: disable-start(screaming-snake-case-const)
    address public constant governor = address(0x1);
    address public constant guardian = address(0x2);
    address public constant user = address(0x3);
    address public constant keeper = address(0x4);
    address public constant executor = address(0x5);
    /// forge-lint: disable-end(screaming-snake-case-const)

    uint16 public immutable CURRENT_CHAIN_ID = uint16(block.chainid);
    uint16 public constant DEST_CHAIN_ID = 10;
    uint16 public constant SOURCE_CHAIN_ID = 111;

    uint256 public constant INITIAL_ROUTER_BALANCE = 500 ether;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistryOld(address(accessManager));

        vm.startPrank(governor);
        router = new BridgeRouter(address(accessManager), address(registry));

        // Adapters
        mockAdapter = new MockAdapter(
            address(registry),
            address(accessManager)
        );
        mockAdapterDest = new MockAdapter(
            address(registry),
            address(accessManager)
        );
        mockAdapterSource = new MockAdapter(
            address(registry),
            address(accessManager)
        );
        mockAdapterNoPeer = new MockAdapter(
            address(registry),
            address(accessManager)
        );

        // Chain support
        mockAdapter.setSupportedChain(SOURCE_CHAIN_ID, true);
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapterDest.setSupportedChain(CURRENT_CHAIN_ID, true);
        mockAdapterSource.setSupportedChain(CURRENT_CHAIN_ID, true);

        // Register current chain adapter with router
        router.registerAdapter(address(mockAdapter));
        // Also register the no-peer adapter (but do not add registry peer mapping)
        router.registerAdapter(address(mockAdapterNoPeer));

        // Registry wiring
        registry.setBridgeRouter(address(router));

        // Register bidirectional adapter peer relationships
        registry.registerAdapterPeerPair(
            address(mockAdapter),
            address(mockAdapterDest),
            CURRENT_CHAIN_ID,
            DEST_CHAIN_ID
        );
        registry.registerAdapterPeerPair(
            address(mockAdapter),
            address(mockAdapterSource),
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID
        );

        // Executors
        registry.registerExecutor(keeper);
        registry.registerExecutor(executor);
        registry.registerExecutor(address(mockAdapter));

        accessManager.grantGuardianRole(guardian);
        accessManager.grantKeeperRole(address(router), keeper);

        // Assets and receiver
        token = new ERC20Mock();
        mockReceiver = new MockCrossChainReceiver();
        token.mint(address(router), INITIAL_ROUTER_BALANCE);

        vm.stopPrank();
    }

    function _makeFailedTransfer(
        bytes32 opId,
        uint256 amount
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: user,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                asset: address(token),
                amount: amount,
                message: ""
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.prank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, payload);

        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        return opId;
    }

    function testIntegration_RecordFailureAndRetry_Succeeds() public {
        // Setup peer relationship for the test
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        // Register recipient (current) <- originator (source)
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        // Register originator (source) -> recipient (current)
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-op1");
        uint256 amount = 10 ether;

        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // Now allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry without overrides
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    // NOTE: Amount override tests removed as only recipient overrides are supported
    // function testIntegration_RetryWithOverridePayload_ChangesAmount() - REMOVED

    // NOTE: Adapter override tests removed as adapter overrides are no longer supported
    // function testIntegration_RetryWithAdapterOverride_FixesMissingPeerMapping() - REMOVED

    function testIntegration_RetryWithRecipientOverride_FixesReceiverRevert()
        public
    {
        // Setup peer relationship for the test
        address fleetProxy = address(0x1003);

        // Create a new receiver for this test to avoid conflicts
        MockCrossChainReceiver testReceiver = new MockCrossChainReceiver();

        vm.startPrank(governor);
        registry.registerRelationship(
            address(testReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        // Register reverse relationship for validation
        registry.registerRelationship(
            fleetProxy,
            address(testReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        // First send to a receiver that reverts, then override recipient to working receiver
        bytes32 opId = keccak256("integration-op4");
        uint256 amount = 2 ether;

        // Configure testReceiver to revert
        testReceiver.setReceiveSuccess(false);

        BridgeTypes.RelayedTransferParams memory pBad = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: fleetProxy, // Use fleetProxy as originator for ark-fleet relationship
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(testReceiver),
                asset: address(token),
                amount: amount,
                message: ""
            });
        bytes memory badPayload = abi.encode(pBad);

        vm.prank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, badPayload);

        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        // Deploy a new receiver that will succeed
        MockCrossChainReceiver goodReceiver = new MockCrossChainReceiver();
        goodReceiver.setReceiveSuccess(true);

        // Unregister the existing relationship for testReceiver first, then register goodReceiver with same fleetProxy
        vm.startPrank(governor);
        registry.unregisterRelationship(
            address(testReceiver),
            registry.PEER_RELATIONSHIP(),
            SOURCE_CHAIN_ID
        );
        // Unregister reverse direction
        registry.unregisterRelationship(
            fleetProxy,
            registry.PEER_RELATIONSHIP(),
            CURRENT_CHAIN_ID
        );

        // Set up peer relationship for the new receiver with the same fleetProxy
        registry.registerRelationship(
            address(goodReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        // Register reverse relationship for validation
        registry.registerRelationship(
            fleetProxy,
            address(goodReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        // Override only the recipient
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(goodReceiver));

        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);
        assertEq(token.balanceOf(address(goodReceiver)), amount);
    }

    // NOTE: Amount override tests removed as only recipient overrides are supported
    // function testIntegration_Transfer_InsufficientBalance_ThenRetryWithLowerAmount() - REMOVED

    function testIntegration_Message_ReceiverRevert_ThenRetry() public {
        // Setup peer relationship for the test
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-op6");

        // Receiver reverts on first attempt
        mockReceiver.setReceiveSuccess(false);

        BridgeTypes.RelayedMessageParams memory m = BridgeTypes
            .RelayedMessageParams({
                operationId: opId,
                originator: fleetProxy, // Use fleetProxy as originator for ark-fleet relationship
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                message: hex"010203"
            });
        bytes memory payload = abi.encode(m);

        vm.prank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.MESSAGE, payload);

        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        // Retry with same payload after enabling receiver
        mockReceiver.setReceiveSuccess(true);
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);
    }

    /* ------------------------------------------------------------ */
    /*                    Payload Validation Integration Tests       */
    /* ------------------------------------------------------------ */

    function testIntegration_RetryWithValidArkFleetRelationship_Succeeds()
        public
    {
        // Setup peer relationship
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-valid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with valid peer relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testIntegration_RetryWithInvalidArkFleetRelationship_Reverts()
        public
    {
        // Setup peer relationship
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);
        address wrongFleet = address(0x9999);

        vm.startPrank(governor);
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-invalid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with invalid peer relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            wrongFleet
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient
        vm.prank(keeper);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, address(0));
    }

    function testIntegration_RetryWithMessagePayload_ValidArkFleet_Succeeds()
        public
    {
        // Setup peer relationship
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-valid-message-ark-fleet");

        // Create failed message with valid peer relationship
        _makeFailedMessageWithArkFleet(opId, address(mockReceiver), fleetProxy);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
    }

    function testIntegration_RetryWithMessagePayload_InvalidArkFleet_Reverts()
        public
    {
        // Setup peer relationship
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);
        address wrongFleet = address(0x9999);

        vm.startPrank(governor);
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-invalid-message-ark-fleet");

        // Create failed message with invalid peer relationship
        _makeFailedMessageWithArkFleet(opId, address(mockReceiver), wrongFleet);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient
        vm.prank(keeper);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, address(0));
    }

    // NOTE: Originator override tests removed as originator overrides are no longer supported
    // function testIntegration_RetryWithOverridePayload_InvalidArkFleet_Reverts() - REMOVED

    function testIntegration_RetryWithOverridePayload_ValidArkFleet_Succeeds()
        public
    {
        // Setup peer relationship
        address arkProxy = address(0x1001);
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        registry.registerRelationship(
            address(mockReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-override-valid-ark-fleet");
        uint256 amount = 10 ether;

        // Create failed transfer with valid relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // No overrides needed - just retry with original parameters
        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should succeed
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success with original amount
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testIntegration_RetryWithNonArkRecipient_Reverts() public {
        bytes32 opId = keccak256("integration-non-ark-recipient");
        uint256 amount = 10 ether;

        // Create failed transfer with non-peer recipient (should now be rejected)
        _makeFailedTransfer(opId, amount);

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry should revert with InvalidRecipient (non-ark recipients are no longer allowed)
        vm.prank(keeper);
        vm.expectRevert(IBridgeRouter.InvalidRecipient.selector);
        router.retryFailedDelivery(opId, address(0));

        // Verify failure record still exists
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);
    }

    function testIntegration_RetryWithNoOverrides_Succeeds() public {
        // Setup peer relationship for the test
        address fleetProxy = address(0x1002);

        vm.startPrank(governor);
        registry.registerRelationship(
            fleetProxy,
            address(mockReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-no-overrides");
        uint256 amount = 7 ether;

        // Create failed transfer with peer relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(mockReceiver),
            fleetProxy
        );

        // Allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry with no overrides
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(0));

        // Verify success with original asset
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testIntegration_RetryWithRecipientOverride_Succeeds() public {
        // Setup peer relationship for the test
        address fleetProxy = address(0x1004);

        // Create a new receiver for this test to avoid conflicts
        MockCrossChainReceiver testReceiver = new MockCrossChainReceiver();

        vm.startPrank(governor);
        registry.registerRelationship(
            address(testReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        // Register reverse relationship for validation
        registry.registerRelationship(
            fleetProxy,
            address(testReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        bytes32 opId = keccak256("integration-recipient-override");
        uint256 amount = 6 ether;

        // Create failed transfer with peer relationship
        _makeFailedTransferWithArkFleet(
            opId,
            amount,
            address(testReceiver),
            fleetProxy
        );

        // Deploy new receiver
        MockCrossChainReceiver newReceiver = new MockCrossChainReceiver();
        newReceiver.setReceiveSuccess(true);

        // Unregister the existing relationship for testReceiver first
        vm.startPrank(governor);
        registry.unregisterRelationship(
            address(testReceiver),
            registry.PEER_RELATIONSHIP(),
            SOURCE_CHAIN_ID
        );
        // Unregister reverse direction
        registry.unregisterRelationship(
            fleetProxy,
            registry.PEER_RELATIONSHIP(),
            CURRENT_CHAIN_ID
        );

        // Set up peer relationship for the new receiver with the same fleet proxy
        // as the original receiver (since we can't override the originator)
        registry.registerRelationship(
            address(newReceiver),
            fleetProxy,
            CURRENT_CHAIN_ID,
            SOURCE_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        // Register reverse relationship for validation
        registry.registerRelationship(
            fleetProxy,
            address(newReceiver),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        // Retry with recipient override only
        vm.prank(keeper);
        router.retryFailedDelivery(opId, address(newReceiver));

        // Verify success with original asset and new receiver
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 0);
        assertEq(token.balanceOf(address(newReceiver)), amount);
        // Original receiver should not have received anything
        assertEq(token.balanceOf(address(testReceiver)), 0);
    }

    /* ------------------------------------------------------------ */
    /*                    Helper Functions for Validation Tests      */
    /* ------------------------------------------------------------ */

    function _makeFailedTransferWithArkFleet(
        bytes32 opId,
        uint256 amount,
        address recipient,
        address originator
    ) internal returns (bytes32) {
        // Configure the specific recipient to fail
        MockCrossChainReceiver(recipient).setReceiveSuccess(false);

        // Build transfer payload with ark-fleet relationship
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: originator,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: recipient,
                asset: address(token),
                amount: amount,
                message: ""
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.prank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, payload);

        // Recorded as failed
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        return opId;
    }

    function _makeFailedMessageWithArkFleet(
        bytes32 opId,
        address recipient,
        address originator
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        // Build message payload with ark-fleet relationship
        BridgeTypes.RelayedMessageParams memory p = BridgeTypes
            .RelayedMessageParams({
                operationId: opId,
                originator: originator,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: recipient,
                message: hex"deadbeef"
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.prank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.MESSAGE, payload);

        // Recorded as failed
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        return opId;
    }
}
