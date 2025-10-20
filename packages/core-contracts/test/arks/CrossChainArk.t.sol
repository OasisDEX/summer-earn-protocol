// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {IArkErrors} from "../../src/errors/IArkErrors.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";
import {ICrossChainArk} from "@summerfi/chain-bridge/interfaces/ICrossChainArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {CrossChainRegistry} from "@summerfi/chain-bridge/contracts/CrossChainRegistry.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {Percentage, PERCENTAGE_1} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {MockAdapter} from "@summerfi/chain-bridge-test/mocks/MockAdapter.sol";
import {ICrossChainConfigManaged} from "@summerfi/chain-bridge/interfaces/ICrossChainConfigManaged.sol";
import {Raft} from "../../src/contracts/Raft.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract CrossChainArkTest is Test, ArkTestBase {
    event InflightCleared(bytes32 operationId, uint256 amount);
    CrossChainArk ark;
    MockBridgeRouter router;
    CrossChainRegistry registry;
    MockAdapter mockAdapter;
    address proxy = address(0x5);
    uint16 constant SOURCE_CHAIN_ID = 31337; // Current chain (mainnet)
    uint16 constant TARGET_CHAIN_ID = 1234; // Target chain (satellite)
    FleetCommander fleetCommander;

    BridgeTypes.BridgeOptions defaultOptions;

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Wraps a uint256 in BridgeTypes.ReadResponse so that
    ///      CrossChainArk.receiveOperation(BridgeTypes.OperationType.READ_STATE,abi.encode( can decode it.
    function _encodeMessage(
        bytes32 operationId,
        address originator,
        address arkAddress,
        uint256 balance,
        uint16 sourceChainId,
        bytes32 latestOutgoingTransferId
    ) internal view returns (BridgeTypes.RelayedMessageParams memory) {
        return
            BridgeTypes.RelayedMessageParams({
                operationId: operationId,
                originator: originator,
                sourceChainId: sourceChainId,
                recipient: arkAddress,
                message: abi.encode(
                    balance,
                    latestOutgoingTransferId,
                    block.timestamp
                )
            });
    }

    function setUp() public {
        initializeCoreContracts();
        router = new MockBridgeRouter();

        // Deploy CrossChainRegistry BEFORE using it
        registry = new CrossChainRegistry(address(accessManager));

        // Initialize the bridge configuration in the registry
        vm.startPrank(governor);
        registry.setBridgeRouter(address(router));
        vm.stopPrank();

        ArkParams memory params = ArkParams({
            name: "TestArk",
            details: "TestArk details",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(mockToken),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: true,
            maxDepositPercentageOfTVL: PERCENTAGE_1
        });

        defaultOptions = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0),
            gasLimit: 0,
            calldataSize: 0,
            msgValue: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });

        ark = new CrossChainArk(address(registry), TARGET_CHAIN_ID, params);

        // Register the ark-proxy relationship in the registry using peer pair registration
        vm.startPrank(governor);
        registry.registerAdapterPeerPair(
            address(ark),
            proxy,
            SOURCE_CHAIN_ID,
            TARGET_CHAIN_ID
        );
        vm.stopPrank();

        // Set up FleetCommander with BufferArk
        (address fleetCommanderAddress, ) = setupFleetCommanderWithBufferArk(
            address(mockToken),
            PERCENTAGE_1,
            "TestFleet"
        );
        fleetCommander = FleetCommander(fleetCommanderAddress);

        // Grant commander role to FleetCommander
        vm.prank(governor);
        accessManager.grantCommanderRole(address(ark), address(fleetCommander));

        // Grant curator role to curator for the fleet commander
        vm.prank(governor);
        accessManager.grantCuratorRole(address(fleetCommander), curator);

        // Grant the ark authorization to board the buffer ark
        vm.prank(governor);
        accessManager.grantCommanderRole(address(fleetCommander), address(ark));

        // Activate the Ark
        vm.prank(governor);
        fleetCommander.addArk(address(ark));

        // Approve the ark to spend its own tokens (needed for sweep function)
        vm.prank(address(ark));
        mockToken.approve(address(ark), type(uint256).max);

        // Deploy mock adapter
        mockAdapter = new MockAdapter(
            address(registry),
            address(accessManager)
        );

        // Register adapter
        router.registerAdapter(address(mockAdapter));
    }

    function testConstructorSetsState() public view {
        assertEq(address(ark.bridgeRouter()), address(router));
        assertEq(address(ark.crossChainRegistry()), address(registry));
        assertEq(ark.satelliteChainId(), TARGET_CHAIN_ID);
        assertEq(ark.getSatelliteProxy(), proxy); // Uses registry lookup
        assertEq(ark.getLastRemoteBalanceUpdateTime(), 0); // Should be 0 initially
    }

    function test_RegistryRelationshipIntegration() public {
        // This test verifies the integration between CrossChainArk and CrossChainRegistry
        // The contract MUST use registry.PEER_RELATIONSHIP() rather than hardcoded constants
        // to ensure maintainability and consistency with registry relationship types

        // Verify the ark can find its target proxy via registry lookup
        address proxyFromRegistry = ark.getSatelliteProxy();
        assertEq(proxyFromRegistry, proxy);

        // Test that the ark can receive assets back from the proxy
        uint256 amount = 500;
        deal(address(mockToken), address(ark), amount);

        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: keccak256("test-receive"),
                originator: proxy,
                sourceChainId: TARGET_CHAIN_ID,
                recipient: address(ark),
                asset: address(mockToken),
                amount: amount,
                message: abi.encode(ark.lastRemoteAssetBalance())
            });

        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.AssetsReceived(
            address(mockToken),
            amount,
            TARGET_CHAIN_ID
        );

        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(params)
        );

        // Verify the transfer was accepted (relationship validation passed)
        assertEq(mockToken.balanceOf(address(ark)), amount);
    }

    function testBoardCallsQueueTransferAssets() public {
        // Approve Ark to spend tokens from FleetCommander

        uint256 amount = 1000;
        deal(address(mockToken), address(fleetCommander), amount);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: amount,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory executeTransferParams = abi.encode(params, options);

        vm.prank(address(fleetCommander));
        ark.board(1000, executeTransferParams);
    }

    function testBoardRejectsPendingTransfer() public {
        uint256 amount = 2000;
        deal(address(mockToken), address(fleetCommander), amount);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: 1000,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory executeTransferParams = abi.encode(params, options);
        vm.prank(address(fleetCommander));
        ark.board(1000, executeTransferParams);

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.PendingTransferAlreadyQueued.selector);
        ark.board(1000, executeTransferParams);
        vm.prank(address(keeper));
        ark.executeTransferAssets();
    }

    function testBoardValidationsFailures() public {
        uint256 amount = 1000;
        deal(address(mockToken), address(fleetCommander), amount);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        // Test 1: Zero amount should revert with InvalidAmount
        BridgeTypes.ExecuteTransferParams memory zeroAmountParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: 0,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory zeroAmountParams_encoded = abi.encode(
            zeroAmountParams,
            options
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidAmount.selector);
        ark.board(0, zeroAmountParams_encoded);

        // Test 2: Amount mismatch should revert with InvalidAmount
        BridgeTypes.ExecuteTransferParams
            memory mismatchAmountParams = BridgeTypes.ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: 500, // Different from board amount
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options2 = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory mismatchAmountParams_encoded = abi.encode(
            mismatchAmountParams,
            options2
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidAmount.selector);
        ark.board(1000, mismatchAmountParams_encoded); // 1000 != 500

        // Test 3: Zero asset address should revert with InvalidAsset
        BridgeTypes.ExecuteTransferParams memory zeroAssetParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(0),
                amount: amount,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options3 = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory zeroAssetParams_encoded = abi.encode(
            zeroAssetParams,
            options3
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidAsset.selector);
        ark.board(amount, zeroAssetParams_encoded);

        // Test 4: Wrong asset address should revert with InvalidAsset
        address wrongAsset = address(0x999);
        BridgeTypes.ExecuteTransferParams memory wrongAssetParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: wrongAsset,
                amount: amount,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options4 = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory wrongAssetParams_encoded = abi.encode(
            wrongAssetParams,
            options4
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidAsset.selector);
        ark.board(amount, wrongAssetParams_encoded);

        // Test 5: Wrong recipient should revert with InvalidRecipient
        address wrongRecipient = address(0x888);
        BridgeTypes.ExecuteTransferParams
            memory wrongRecipientParams = BridgeTypes.ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: amount,
                target: wrongRecipient,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options5 = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory wrongRecipientParams_encoded = abi.encode(
            wrongRecipientParams,
            options5
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidRecipient.selector);
        ark.board(amount, wrongRecipientParams_encoded);

        // Test 6: Wrong originator should revert with InvalidRequestor
        address wrongOriginator = address(0x777);
        BridgeTypes.ExecuteTransferParams
            memory wrongOriginatorParams = BridgeTypes.ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: amount,
                target: proxy,
                originator: wrongOriginator,
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options6 = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory wrongOriginatorParams_encoded = abi.encode(
            wrongOriginatorParams,
            options6
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidRequestor.selector);
        ark.board(amount, wrongOriginatorParams_encoded);

        // Test 7: Wrong destination chain ID should revert with InvalidSatelliteChain
        uint16 wrongChainId = 9999;
        BridgeTypes.ExecuteTransferParams memory wrongChainParams = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: wrongChainId,
                asset: address(mockToken),
                amount: amount,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options7 = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory wrongChainParams_encoded = abi.encode(
            wrongChainParams,
            options7
        );

        vm.prank(address(fleetCommander));
        vm.expectRevert(ICrossChainArk.InvalidSatelliteChain.selector);
        ark.board(amount, wrongChainParams_encoded);
    }

    function testReceiveStateReadUpdatesRemoteBalanceAndEmitsEvent() public {
        uint256 remoteBalance = 12345;
        bytes32 requestId = keccak256("test-request");
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            remoteBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );

        uint16 sourceChain = TARGET_CHAIN_ID;

        // Should emit the event and update the state
        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.RemoteAssetBalanceUpdated(remoteBalance, requestId);

        // Call as bridgeRouter, with correct sourceChain and requestor
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );

        // Check state
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
    }

    function testReceiveMessageWithAssets() public {
        address tokenAddress = address(mockToken);
        uint256 amount = 500;

        uint16 sourceChain = TARGET_CHAIN_ID;
        bytes32 requestId = keccak256("test-request");

        // Track initial state
        uint256 initialRemoteBalance = 1000;
        uint256 remoteBalanceAfterWithdrawal = initialRemoteBalance - amount;
        bytes memory message = abi.encode(remoteBalanceAfterWithdrawal);

        // Set initial remote balance
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            initialRemoteBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );

        // Should emit the remote balance update and assets received events when receiving assets
        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.RemoteAssetBalanceUpdated(
            remoteBalanceAfterWithdrawal,
            requestId
        );
        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.AssetsReceived(tokenAddress, amount, sourceChain);

        // Mock token transfer that would happen in a real bridge
        deal(address(mockToken), address(ark), amount);

        // Call as bridgeRouter
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(
                BridgeTypes.RelayedTransferParams({
                    operationId: requestId,
                    originator: address(proxy),
                    sourceChainId: sourceChain,
                    recipient: address(ark),
                    asset: tokenAddress,
                    amount: amount,
                    message: message
                })
            )
        );

        // Check state was updated correctly
        assertEq(ark.lastRemoteAssetBalance(), initialRemoteBalance - amount);
    }

    //----------------- Satellite Receipt Notify (Ark → Proxy) -----------------//

    function test_NotifySatelliteReceipt_SendsAckMessage() public {
        // Simulate receiving a withdrawal from satellite so that latestIncomingTransferId is set
        uint256 amount = 500;
        bytes32 opId = keccak256("withdrawal-op");
        bytes memory message = abi.encode(uint256(1000));

        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: proxy,
                sourceChainId: TARGET_CHAIN_ID,
                recipient: address(ark),
                asset: address(mockToken),
                amount: amount,
                message: message
            });

        // deliver transfer from router
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(params)
        );

        // Ensure latestIncomingTransferId set
        bytes32 latestIn = ark.latestIncomingTransferId();
        assertEq(latestIn, opId);

        // Call notifySatelliteChain as keeper
        vm.deal(keeper, 1 ether);
        vm.prank(keeper);
        ark.notifySatelliteChain{value: 0.1 ether}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 200000,
                calldataSize: 0,
                msgValue: 0,
                options: "",
                payInProtocolToken: false,
                feeTokenAmount: 0
            })
        );

        // The mock router records messageCalls, check count increased
        uint256 count = router.getMessageCallCount();
        assertEq(count, 1, "one message should be sent");

        // Verify payload contains opId
        (, , bytes memory sentMessage) = router.messageCalls(count - 1);
        bytes32 decodedOpId = abi.decode(sentMessage, (bytes32));
        assertEq(decodedOpId, opId, "ACK payload should contain opId");
    }

    function test_NotifySatelliteReceipt_RequiresLatestIncomingTransferId()
        public
    {
        // Without prior inbound transfer, calling notify should revert
        vm.deal(keeper, 1 ether);
        vm.prank(keeper);
        vm.expectRevert(ICrossChainArk.InvalidRequestor.selector);
        ark.notifySatelliteChain{value: 0.1 ether}(
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(mockAdapter),
                gasLimit: 200000,
                calldataSize: 0,
                msgValue: 0,
                options: "",
                payInProtocolToken: false,
                feeTokenAmount: 0
            })
        );
    }

    // ========================================================================
    // ENHANCED READ DELIVERY TESTS
    // ========================================================================

    function testReceiveStateReadWithCorrectParameterOrder() public {
        uint256 remoteBalance = 54321;
        bytes32 requestId = keccak256("parameter-order-test");
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            remoteBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );
        uint16 sourceChain = TARGET_CHAIN_ID;

        // Test the correct parameter order: (resultData, requestor, requestId, sourceChainId)
        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.RemoteAssetBalanceUpdated(remoteBalance, requestId);

        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );

        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
        assertEq(
            ark.inflightAssets(),
            0,
            "Inflight assets should be reset to 0"
        );
    }

    function testReceiveStateReadResetsInflightAssets() public {
        uint256 remoteBalance = 2000;
        bytes32 requestId = keccak256("inflight-reset-test");
        uint16 sourceChain = TARGET_CHAIN_ID;

        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            remoteBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );

        // Set some inflight assets first (governor-only emergency function)
        vm.prank(governor);
        ark.forceUpdateInflightAssets(500);
        assertEq(
            ark.inflightAssets(),
            500,
            "Setup: inflight assets should be 500"
        );

        // Receive state read should reset inflight assets (new event semantics)
        vm.expectEmit(true, true, true, true);
        emit InflightCleared(requestId, 500);

        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );

        assertEq(
            ark.inflightAssets(),
            0,
            "Inflight assets should be reset after state read"
        );
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
    }

    function testReceiveStateReadUnauthorizedCaller() public {
        uint256 remoteBalance = 1000;
        bytes32 requestId = keccak256("unauthorized-test");
        uint16 sourceChain = TARGET_CHAIN_ID;
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            remoteBalance,
            sourceChain,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );

        // Test unauthorized caller
        vm.prank(address(0x999));
        vm.expectRevert(ICrossChainReceiver.Unauthorized.selector);
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );
    }

    function testReceiveStateReadInvalidSourceChain() public {
        uint256 remoteBalance = 1000;
        bytes32 requestId = keccak256("wrong-chain-test");
        uint16 wrongSourceChain = 9999;
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            remoteBalance,
            wrongSourceChain,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );

        // Test wrong source chain
        vm.prank(address(router));
        vm.expectRevert(ICrossChainArk.InvalidSourceChain.selector);
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );
    }

    function testSupportsInterfaceIncludesStateReadReceiver() public view {
        // Test that the contract properly reports support for all interfaces
        assertTrue(
            ark.supportsInterface(type(ICrossChainReceiver).interfaceId),
            "Should support ICrossChainReceiver"
        );
        assertTrue(
            ark.supportsInterface(type(ICrossChainArk).interfaceId),
            "Should support ICrossChainArk"
        );
        // Note: ICrossChainReceiver interface support is tested in other tests
    }

    function testTotalAssetsIncludesAllComponents() public {
        uint256 localBalance = 1000;
        uint256 remoteBalance = 2000;
        uint256 inflightAmount = 500;

        // Setup local balance
        deal(address(mockToken), address(ark), localBalance);

        // Setup remote balance via state read
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            bytes32(0),
            address(proxy),
            address(ark),
            remoteBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );

        // Setup inflight assets (governor-only emergency function)
        vm.prank(governor);
        ark.forceUpdateInflightAssets(inflightAmount);

        // Test total assets calculation
        uint256 expectedTotal = localBalance + remoteBalance + inflightAmount;
        assertEq(
            ark.totalAssets(),
            expectedTotal,
            "Total assets should include local + remote + inflight"
        );
    }

    function testBridgeRouterDeliveryFlow() public {
        // This test simulates what would happen when BridgeRouter calls deliver()
        // and that results in CrossChainArk.receiveOperation(BridgeTypes.OperationType.READ_STATE,abi.encode( being called
        uint256 remoteBalance = 7777;
        bytes32 requestId = keccak256("delivery-flow-test");
        BridgeTypes.RelayedMessageParams memory params = _encodeMessage(
            requestId,
            address(proxy),
            address(ark),
            remoteBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );

        // In the real flow:
        // 1. CrossChainArk requests a state read via BridgeRouter
        // 2. BridgeRouter executes the read request
        // 3. When response comes back, BridgeRouter.deliver() calls receiveStateRead

        // For this test, we simulate step 3 directly
        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.RemoteAssetBalanceUpdated(remoteBalance, requestId);

        // Simulate BridgeRouter calling receiveStateRead on the CrossChainArk
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );

        // Verify the state was updated correctly
        assertEq(ark.lastRemoteAssetBalance(), remoteBalance);
        assertEq(ark.inflightAssets(), 0);
    }

    function testInterfaceSupport() public view {
        // Test all the interfaces the CrossChainArk should support
        assertTrue(
            ark.supportsInterface(type(ICrossChainReceiver).interfaceId),
            "Should support ICrossChainReceiver"
        );
        assertTrue(
            ark.supportsInterface(type(ICrossChainArk).interfaceId),
            "Should support ICrossChainArk"
        );
        assertTrue(
            ark.supportsInterface(type(IERC165).interfaceId),
            "Should support IERC165"
        );

        // Test that it reports false for unsupported interfaces
        assertFalse(
            ark.supportsInterface(bytes4(0xffffffff)),
            "Should not support random interface"
        );
    }

    function _buildEmptyPayload() internal pure returns (bytes memory) {
        return bytes("");
    }

    // ========================================================================
    // cancelPendingTransfer TESTS
    // ========================================================================

    function testCancelPendingTransferUnauthorized() public {
        address unauthorized = address(0xBEEF);
        vm.prank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotKeeper(address)", unauthorized)
        );
        ark.cancelPendingTransfer();
    }

    function testCancelPendingTransferNoPending() public {
        vm.prank(address(keeper));
        vm.expectRevert(ICrossChainArk.NoPendingTransferQueued.selector);
        ark.cancelPendingTransfer();
    }

    function testCancelPendingTransferAfterQueue() public {
        uint256 amount = 1000;
        deal(address(mockToken), address(fleetCommander), amount);
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        // Create pending transfer params
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: amount,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: ""
        });
        bytes memory executeTransferParams = abi.encode(params, options);

        // Board the transfer (this queues it but doesn't execute)
        vm.prank(address(fleetCommander));
        ark.board(amount, executeTransferParams);

        // Record initial balances
        uint256 initialArkBalance = mockToken.balanceOf(address(ark));
        uint256 initialBufferBalance = mockToken.balanceOf(
            fleetCommander.bufferArk()
        );

        // Verify pending transfer is queued
        (
            address originator,
            uint16 destinationChainId,
            address target,
            address asset,
            uint256 pendingAmount,
            bytes memory message,
            address refundAddress
        ) = ark.pendingTransferParams();

        assertTrue(asset != address(0), "Pending transfer should be queued");
        assertEq(pendingAmount, amount, "Pending amount should match");

        // Cancel the pending transfer
        vm.prank(keeper);
        ark.cancelPendingTransfer();

        // Verify assets were returned to buffer ark
        uint256 finalArkBalance = mockToken.balanceOf(address(ark));
        uint256 finalBufferBalance = mockToken.balanceOf(
            fleetCommander.bufferArk()
        );

        assertEq(
            finalArkBalance,
            initialArkBalance - amount,
            "Ark balance should decrease by transfer amount"
        );
        assertEq(
            finalBufferBalance,
            initialBufferBalance + amount,
            "Buffer balance should increase by transfer amount"
        );

        // Verify pending transfer params are reset
        (
            address originatorAfter,
            uint16 destinationChainIdAfter,
            address targetAfter,
            address assetAfter,
            uint256 pendingAmountAfter,
            bytes memory messageAfter,
            address refundAddressAfter
        ) = ark.pendingTransferParams();

        assertEq(assetAfter, address(0), "Pending transfer should be cleared");
        assertEq(pendingAmountAfter, 0, "Pending amount should be zero");
    }

    function testDisembarkWhileTransferPendingVulnerability() public {
        // Setup: Fund the ark with initial assets
        uint256 initialArkBalance = 2000e18; // 2000 tokens
        deal(address(mockToken), address(ark), initialArkBalance);

        // Setup: Fund the FleetCommander with tokens for boarding
        uint256 fleetCommanderBalance = 2000e18; // 2000 tokens (enough for the transfer)
        deal(
            address(mockToken),
            address(fleetCommander),
            fleetCommanderBalance
        );
        vm.prank(address(fleetCommander));
        mockToken.approve(address(ark), type(uint256).max);

        // Step 1: Initiate a transfer (board) but don't execute it yet
        uint256 transferAmount = 1500e18; // 1500 tokens to transfer
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                destinationChainId: TARGET_CHAIN_ID,
                asset: address(mockToken),
                amount: transferAmount,
                target: proxy,
                originator: address(ark),
                refundAddress: commander,
                message: ""
            });
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 200000,
            msgValue: 0,
            calldataSize: 0,
            options: "",
            payInProtocolToken: false,
            feeTokenAmount: 0
        });
        bytes memory executeTransferParams = abi.encode(params, options);

        // Board the transfer (this queues it but doesn't execute)
        vm.prank(address(fleetCommander));
        ark.board(transferAmount, executeTransferParams);

        // Step 2: Disembark a significant amount from the ark
        // This reduces the ark's local balance below what's needed for the pending transfer
        uint256 disembarkAmount = 2500e18; // Disembark more than enough to create insufficient balance
        vm.prank(address(fleetCommander));
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainArk.PendingTransferAlreadyQueued.selector
            )
        );
        ark.disembark(disembarkAmount, bytes("keeper_data")); // CrossChainArk requires keeper data

        // Step 3: This test EXPECTS the transfer to succeed
        vm.prank(keeper);
        ark.executeTransferAssets();

        (, , , address assetAfterExecution, , , ) = ark.pendingTransferParams();
        assertTrue(
            assetAfterExecution == address(0),
            "Transfer should have succeeded"
        );
    }

    function test_SweepPreventedForUnderlyingAsset() public {
        // Setup: Create a different token (not the ark's main asset) to sweep
        ERC20Mock otherToken = new ERC20Mock();
        deal(address(otherToken), address(ark), 1000e18);

        // Setup sweepable token in Raft for both tokens
        vm.prank(curator);
        Raft(raft).setSweepableToken(address(ark), address(otherToken), true);
        vm.prank(curator);
        Raft(raft).setSweepableToken(address(ark), address(mockToken), true);

        // Step 1: Try to sweep the underlying asset (should fail)
        address[] memory underlyingAssetToSweep = new address[](1);
        underlyingAssetToSweep[0] = address(mockToken);

        // This should revert because we're trying to sweep the underlying asset
        vm.prank(address(raft));
        vm.expectRevert(
            abi.encodeWithSelector(
                IArkErrors.CannotSweepUnderlyingAsset.selector
            )
        );
        ark.sweep(underlyingAssetToSweep);

        // Step 2: Try to sweep other tokens (should work)
        address[] memory otherTokensToSweep = new address[](1);
        otherTokensToSweep[0] = address(otherToken);

        vm.prank(address(raft));
        (address[] memory sweptTokens, uint256[] memory sweptAmounts) = ark
            .sweep(otherTokensToSweep);

        assertEq(sweptTokens.length, 1, "Should have swept 1 token");
        assertEq(
            sweptTokens[0],
            address(otherToken),
            "Should have swept otherToken"
        );
        assertGt(sweptAmounts[0], 0, "Should have swept some amount");
    }

    function test_SweepAllowsOtherTokens() public {
        // Setup: Create a different token (not the ark's main asset) to sweep
        ERC20Mock otherToken = new ERC20Mock();
        deal(address(otherToken), address(ark), 1000e18);

        // Setup sweepable token in Raft
        vm.prank(curator);
        Raft(raft).setSweepableToken(address(ark), address(otherToken), true);

        // Step 1: Try to sweep other tokens (should work)
        address[] memory tokensToSweep = new address[](1);
        tokensToSweep[0] = address(otherToken);

        vm.prank(address(raft));
        (address[] memory sweptTokens, uint256[] memory sweptAmounts) = ark
            .sweep(tokensToSweep);

        assertEq(sweptTokens.length, 1, "Should have swept 1 token");
        assertEq(
            sweptTokens[0],
            address(otherToken),
            "Should have swept otherToken"
        );
        assertGt(sweptAmounts[0], 0, "Should have swept some amount");
    }

    function testStaleNotificationProtection() public {
        uint256 initialBalance = 1000;
        uint256 newBalance = 2000;
        bytes32 requestId1 = keccak256("stale-test-1");
        bytes32 requestId2 = keccak256("stale-test-2");

        // First, set up a valid notification
        BridgeTypes.RelayedMessageParams memory params1 = _encodeMessage(
            requestId1,
            address(proxy),
            address(ark),
            initialBalance,
            TARGET_CHAIN_ID,
            bytes32(0) // latestOutgoingTransferId is not set yet
        );

        // Process the first notification
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params1)
        );

        assertEq(ark.lastRemoteAssetBalance(), initialBalance);
        assertEq(ark.lastNotificationTimestamp(), block.timestamp);

        // Now try to send a stale notification with an older timestamp
        vm.warp(block.timestamp + 100); // Advance time to 101

        // Create the stale message directly without using _encodeMessage
        uint256 staleTimestamp = 0; // This should be 0, which is older than 1

        bytes memory staleMessage = abi.encode(
            newBalance,
            bytes32(0),
            staleTimestamp
        );

        BridgeTypes.RelayedMessageParams memory params2 = BridgeTypes
            .RelayedMessageParams({
                operationId: requestId2,
                originator: address(proxy),
                sourceChainId: TARGET_CHAIN_ID,
                recipient: address(ark),
                message: staleMessage
            });

        // Expect the StaleNotification event
        vm.expectEmit(true, true, true, true);
        emit ICrossChainArk.StaleNotification(
            staleTimestamp, // 0
            1 // lastNotificationTimestamp was 1
        );

        // Process the stale notification - should be rejected
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params2)
        );

        // Verify the balance wasn't updated
        assertEq(ark.lastRemoteAssetBalance(), initialBalance);
        assertEq(ark.lastNotificationTimestamp(), 1);
    }
}
