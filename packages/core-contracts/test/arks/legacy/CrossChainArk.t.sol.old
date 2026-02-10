// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {CrossChainArk} from "../../src/contracts/arks/CrossChainArk.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";
import {ICrossChainArk} from "@summerfi/chain-bridge/interfaces/ICrossChainArk.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {CrossChainRegistry} from "@summerfi/chain-bridge/contracts/CrossChainRegistry.sol";
import {ArkParams} from "../../src/types/ArkTypes.sol";
import {ArkTestBase} from "./ArkTestBase.sol";
import {Percentage, PERCENTAGE_1} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {MockAdapter} from "@summerfi/chain-bridge-test/mocks/MockAdapter.sol";
import {ICrossChainConfigManaged} from "@summerfi/chain-bridge/interfaces/ICrossChainConfigManaged.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";

contract CrossChainArkTest is Test, ArkTestBase {
    CrossChainArk ark;
    MockBridgeRouter router;
    CrossChainRegistry registry;
    MockAdapter mockAdapter;
    address proxy = address(0x5);
    uint16 constant SOURCE_CHAIN_ID = 1; // Current chain (mainnet)
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
    ) internal pure returns (BridgeTypes.RelayedMessageParams memory) {
        return
            BridgeTypes.RelayedMessageParams({
                operationId: operationId,
                originator: originator,
                sourceChainId: sourceChainId,
                recipient: arkAddress,
                message: abi.encode(balance, latestOutgoingTransferId)
            });
    }

    function setUp() public {
        initializeCoreContracts();
        router = new MockBridgeRouter();

        // Deploy CrossChainRegistry BEFORE using it
        registry = new CrossChainRegistry(
            address(accessManager),
            SOURCE_CHAIN_ID // Current chain ID
        );

        // Initialize the bridge configuration in the registry
        vm.startPrank(governor);
        registry.initializeBridgeConfiguration(
            address(router),
            200000 // defaultGasLimit
        );
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
            options: ""
        });

        ark = new CrossChainArk(
            address(router),
            address(registry),
            TARGET_CHAIN_ID,
            params
        );

        // Register the ark-proxy relationship in the registry
        vm.prank(governor);
        registry.registerRelationship(
            address(ark),
            proxy,
            SOURCE_CHAIN_ID,
            TARGET_CHAIN_ID,
            keccak256("ARK_FLEET_RELATIONSHIP")
        );

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

        // Activate the Ark
        vm.prank(governor);
        fleetCommander.addArk(address(ark));

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
        assertEq(ark.getTargetProxy(), proxy); // Uses registry lookup
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
            options: ""
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
            options: ""
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
            options: ""
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
            options: ""
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
            options: ""
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
            options: ""
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
            options: ""
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
            options: ""
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
            options: ""
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

        // Should emit the event when receiving assets
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

        // Set some inflight assets first
        vm.prank(address(router));
        ark.updateInflightAssets(500);
        assertEq(
            ark.inflightAssets(),
            500,
            "Setup: inflight assets should be 500"
        );

        // Receive state read should reset inflight assets
        vm.expectEmit(true, true, true, true);
        emit IInflightAssetTracking.InflightAssetsUpdated(0);

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

        // Setup inflight assets
        vm.prank(address(router));
        ark.updateInflightAssets(inflightAmount);

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
        BridgeTypes.DeliverPayload memory dp = BridgeTypes.DeliverPayload({
            operationId: bytes32(0),
            originator: address(0),
            sourceAsset: address(0)
        });
        return abi.encode(dp);
    }
}
