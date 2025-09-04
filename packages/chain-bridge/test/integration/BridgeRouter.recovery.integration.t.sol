// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {MockAdapter} from "../mocks/MockAdapter.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract BridgeRouterRecoveryIntegrationTest is Test {
    BridgeRouter public router;
    ProtocolAccessManager public accessManager;
    CrossChainRegistry public registry;

    MockAdapter public mockAdapter; // current chain adapter (registered)
    MockAdapter public mockAdapterDest; // remote adapter (peer)
    MockAdapter public mockAdapterSource; // source chain adapter (peer)
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
    uint256 public constant DEFAULT_GAS_LIMIT = 500000;

    uint256 public constant INITIAL_ROUTER_BALANCE = 500 ether;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistry(
            address(accessManager),
            CURRENT_CHAIN_ID
        );

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

        // Chain support
        mockAdapter.setSupportedChain(SOURCE_CHAIN_ID, true);
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapterDest.setSupportedChain(CURRENT_CHAIN_ID, true);
        mockAdapterSource.setSupportedChain(CURRENT_CHAIN_ID, true);

        // Register current chain adapter with router
        router.registerAdapter(address(mockAdapter));

        // Registry wiring
        registry.initializeBridgeConfiguration(
            address(router),
            DEFAULT_GAS_LIMIT
        );

        // CURRENT -> DEST
        registry.registerAdapterPeer(
            address(mockAdapter),
            address(mockAdapterDest),
            CURRENT_CHAIN_ID,
            DEST_CHAIN_ID
        );
        // DEST -> CURRENT
        registry.registerAdapterPeer(
            address(mockAdapterDest),
            address(mockAdapter),
            DEST_CHAIN_ID,
            CURRENT_CHAIN_ID
        );
        // SOURCE -> CURRENT
        registry.registerAdapterPeer(
            address(mockAdapterSource),
            address(mockAdapter),
            SOURCE_CHAIN_ID,
            CURRENT_CHAIN_ID
        );
        // CURRENT -> SOURCE
        registry.registerAdapterPeer(
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
        bytes32 opId = keccak256("integration-op1");
        uint256 amount = 10 ether;

        _makeFailedTransfer(opId, amount);

        // Now allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry without overrides
        vm.prank(governor);
        router.retryFailedDelivery(opId, "");

        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testIntegration_RetryWithOverridePayload_ChangesAmount() public {
        bytes32 opId = keccak256("integration-op2");
        uint256 originalAmount = 10 ether;
        _makeFailedTransfer(opId, originalAmount);

        uint256 correctedAmount = 7 ether;
        BridgeTypes.RelayedTransferParams memory corrected = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: user,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                asset: address(token),
                amount: correctedAmount,
                message: ""
            });
        bytes memory correctedPayload = abi.encode(corrected);

        // Encode overrideData as tuple (address adapter, bytes payload)
        bytes memory overrideData = abi.encode(address(0), correctedPayload);

        mockReceiver.setReceiveSuccess(true);

        vm.prank(governor);
        router.retryFailedDelivery(opId, overrideData);

        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), correctedAmount);
    }
}
