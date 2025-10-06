// SPDX-License-Identifier: BUSL-1.1
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
import {Percentage, PERCENTAGE_1} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {MockAdapter} from "@summerfi/chain-bridge-test/mocks/MockAdapter.sol";
import {ICrossChainConfigManaged} from "@summerfi/chain-bridge/interfaces/ICrossChainConfigManaged.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "../../src/contracts/ConfigurationManager.sol";
import {ConfigurationManagerParams} from "../../src/types/ConfigurationManagerTypes.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {FleetCommanderRewardsManagerFactory} from "../../src/contracts/FleetCommanderRewardsManagerFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title CrossChainArkSyncStatusTest
 * @notice Test suite for CrossChainArk sync status functionality
 * @dev Tests the isSynced() function with various scenarios including timestamp tracking
 */
contract CrossChainArkSyncStatusTest is Test, TestHelpers {
    event RemoteAssetBalanceUpdated(uint256 balance, bytes32 operationId);
    event InflightSet(uint256 amount, bytes32 operationId);
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

    // Test addresses
    address public governor = address(1);
    address public guardian = address(1);
    address public commander = address(4);
    address public raft = address(2);
    address public tipJar = address(3);
    address public treasury = address(5);
    address public keeper = address(6);
    address public curator = address(7);

    // Contract instances
    ProtocolAccessManager public accessManager;
    HarborCommand public harborCommand;
    FleetCommanderRewardsManagerFactory
        public fleetCommanderRewardsManagerFactory;
    ConfigurationManager public configurationManager;
    ERC20Mock public mockToken;

    function setUp() public {
        // Initialize mock token
        mockToken = new ERC20Mock();

        // Setup basic contracts
        accessManager = new ProtocolAccessManager(governor);
        harborCommand = new HarborCommand(address(accessManager));
        fleetCommanderRewardsManagerFactory = new FleetCommanderRewardsManagerFactory();
        configurationManager = new ConfigurationManager(address(accessManager));

        vm.prank(governor);
        configurationManager.initializeConfiguration(
            ConfigurationManagerParams({
                raft: address(raft),
                tipJar: address(tipJar),
                treasury: treasury,
                harborCommand: address(harborCommand),
                fleetCommanderRewardsManagerFactory: address(
                    fleetCommanderRewardsManagerFactory
                )
            })
        );

        setupCrossChainArk();
    }

    function setupCrossChainArk() internal {
        // Setup bridge components
        router = new MockBridgeRouter();
        registry = new CrossChainRegistry(address(accessManager));

        // Initialize the bridge configuration in the registry
        vm.startPrank(governor);
        registry.setBridgeRouter(address(router));
        vm.stopPrank();

        // Deploy mock adapter
        mockAdapter = new MockAdapter(
            address(registry),
            address(accessManager)
        );

        // Register adapter
        router.registerAdapter(address(mockAdapter));

        // Create Ark first
        ArkParams memory params = ArkParams({
            name: "CrossChainArk",
            details: "CrossChainArk details",
            accessManager: address(accessManager),
            asset: address(mockToken),
            configurationManager: address(configurationManager),
            depositCap: 100000 * 10 ** 6,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PERCENTAGE_1
        });

        ark = new CrossChainArk(address(registry), TARGET_CHAIN_ID, params);

        // Setup registry relationships
        vm.startPrank(governor);
        registry.registerRelationship(
            address(ark), // source
            proxy,
            SOURCE_CHAIN_ID,
            TARGET_CHAIN_ID,
            registry.PEER_RELATIONSHIP()
        );
        vm.stopPrank();

        // Setup default options
        defaultOptions = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 400000,
            calldataSize: 0,
            msgValue: 0,
            options: bytes("")
        });
    }

    /*//////////////////////////////////////////////////////////////
                            SYNC STATUS TESTS
    //////////////////////////////////////////////////////////////*/

    function testIsSyncedInitiallyUnsynced() public {
        // Initially, no remote balance has been received
        assertFalse(
            ark.isSynced(),
            "Should be unsynced initially (no remote balance)"
        );
        assertEq(
            ark.lastRemoteBalanceUpdateTime(),
            0,
            "Should have no update time initially"
        );
    }

    function testIsSyncedWithInflightAssets() public {
        // Set inflight assets
        vm.prank(governor);
        ark.forceUpdateInflightAssets(1000 * 10 ** 6);

        assertFalse(ark.isSynced(), "Should be unsynced with inflight assets");
        assertTrue(ark.inflightAssets() > 0, "Should have inflight assets");
    }

    function testIsSyncedWithRecentUpdate() public {
        // Simulate receiving a remote balance update
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);

        assertTrue(ark.isSynced(), "Should be synced with recent update");
        assertEq(
            ark.lastRemoteAssetBalance(),
            1000 * 10 ** 6,
            "Should have correct balance"
        );
        assertTrue(
            ark.lastRemoteBalanceUpdateTime() > 0,
            "Should have update time"
        );
    }

    function testIsSyncedWithStaleUpdate() public {
        // Simulate receiving a remote balance update
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);

        // Fast forward past sync window (24 hours + 1 second)
        vm.warp(block.timestamp + ark.SYNC_WINDOW() + 1);

        assertFalse(ark.isSynced(), "Should be unsynced with stale update");
    }

    function testIsSyncedWithInflightAndRecentUpdate() public {
        // Set inflight assets
        vm.prank(governor);
        ark.forceUpdateInflightAssets(1000 * 10 ** 6);

        // Should be unsynced due to inflight assets (don't simulate balance update as it would clear inflight)
        assertFalse(ark.isSynced(), "Should be unsynced with inflight assets");
        assertTrue(ark.inflightAssets() > 0, "Should have inflight assets");
    }

    function testIsSyncedAfterInflightCleared() public {
        // Set inflight assets
        vm.prank(governor);
        ark.forceUpdateInflightAssets(1000 * 10 ** 6);

        assertFalse(ark.isSynced(), "Should be unsynced with inflight assets");

        // Simulate receiving balance update which clears inflight
        _simulateRemoteBalanceUpdate(2000 * 10 ** 6);

        assertTrue(ark.isSynced(), "Should be synced after inflight cleared");
        assertEq(ark.inflightAssets(), 0, "Should have no inflight assets");
    }

    function testIsSyncedWithTransferAssetUpdate() public {
        // Simulate receiving assets via transfer
        _simulateTransferAsset(1000 * 10 ** 6, 500 * 10 ** 6);

        assertTrue(
            ark.isSynced(),
            "Should be synced with recent transfer update"
        );
        assertEq(
            ark.lastRemoteAssetBalance(),
            1000 * 10 ** 6,
            "Should have correct balance"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            TIMESTAMP TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    function testTimestampTrackingOnMessage() public {
        uint256 initialTime = block.timestamp;

        // Simulate receiving a message
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);

        assertEq(
            ark.lastRemoteBalanceUpdateTime(),
            initialTime,
            "Should track timestamp on message"
        );
    }

    function testTimestampTrackingOnTransfer() public {
        uint256 initialTime = block.timestamp;

        // Simulate receiving a transfer
        _simulateTransferAsset(1000 * 10 ** 6, 500 * 10 ** 6);

        assertEq(
            ark.lastRemoteBalanceUpdateTime(),
            initialTime,
            "Should track timestamp on transfer"
        );
    }

    function testTimestampUpdatesOnMultipleMessages() public {
        uint256 initialTime = block.timestamp;

        // First message
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);
        assertEq(
            ark.lastRemoteBalanceUpdateTime(),
            initialTime,
            "Should track first message"
        );

        // Fast forward and send second message
        vm.warp(block.timestamp + 1 hours);
        uint256 secondTime = block.timestamp;
        _simulateRemoteBalanceUpdate(2000 * 10 ** 6);

        assertEq(
            ark.lastRemoteBalanceUpdateTime(),
            secondTime,
            "Should update timestamp on second message"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            SYNC WINDOW TESTS
    //////////////////////////////////////////////////////////////*/

    function testSyncWindowConstant() public {
        assertEq(ark.SYNC_WINDOW(), 24 hours, "Sync window should be 24 hours");
    }

    function testIsSyncedAtSyncWindowBoundary() public {
        // Simulate receiving a remote balance update
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);

        // Fast forward to exactly sync window
        vm.warp(block.timestamp + ark.SYNC_WINDOW());

        assertTrue(ark.isSynced(), "Should be synced at sync window boundary");
    }

    function testIsSyncedJustPastSyncWindow() public {
        // Simulate receiving a remote balance update
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);

        // Fast forward just past sync window
        vm.warp(block.timestamp + ark.SYNC_WINDOW() + 1);

        assertFalse(ark.isSynced(), "Should be unsynced just past sync window");
    }

    function testIsSyncedWithMultipleUpdates() public {
        // First update
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);
        assertTrue(ark.isSynced(), "Should be synced after first update");

        // Fast forward 12 hours and update again
        vm.warp(block.timestamp + 12 hours);
        _simulateRemoteBalanceUpdate(2000 * 10 ** 6);
        assertTrue(ark.isSynced(), "Should be synced after second update");

        // Fast forward another 12 hours (total 24 hours from first update)
        vm.warp(block.timestamp + 12 hours);
        assertTrue(
            ark.isSynced(),
            "Should still be synced (within window from second update)"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function testIsSyncedWithZeroBalance() public {
        // Simulate receiving zero balance
        _simulateRemoteBalanceUpdate(0);

        assertTrue(ark.isSynced(), "Should be synced with zero balance");
        assertEq(ark.lastRemoteAssetBalance(), 0, "Should have zero balance");
    }

    function testIsSyncedWithLargeBalance() public {
        // Simulate receiving large balance
        uint256 largeBalance = type(uint256).max / 2;
        _simulateRemoteBalanceUpdate(largeBalance);

        assertTrue(ark.isSynced(), "Should be synced with large balance");
        assertEq(
            ark.lastRemoteAssetBalance(),
            largeBalance,
            "Should have large balance"
        );
    }

    function testIsSyncedWithInvalidTransferId() public {
        // Simulate message with invalid transfer ID (should not update balance)
        bytes32 invalidTransferId = bytes32(uint256(999));
        _simulateMessageWithTransferId(1000 * 10 ** 6, invalidTransferId);

        assertFalse(
            ark.isSynced(),
            "Should be unsynced with invalid transfer ID"
        );
        assertEq(
            ark.lastRemoteAssetBalance(),
            0,
            "Should not update balance with invalid transfer ID"
        );
    }

    function testIsSyncedWithValidTransferId() public {
        // First, set a valid outgoing transfer ID
        ark.setLatestOutgoingTransferId(bytes32(uint256(123)));

        // Simulate message with matching transfer ID
        _simulateMessageWithTransferId(1000 * 10 ** 6, bytes32(uint256(123)));

        assertTrue(ark.isSynced(), "Should be synced with valid transfer ID");
        assertEq(
            ark.lastRemoteAssetBalance(),
            1000 * 10 ** 6,
            "Should update balance with valid transfer ID"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testFullSyncCycle() public {
        // Start unsynced
        assertFalse(ark.isSynced(), "Should start unsynced");

        // Simulate inflight transfer
        vm.prank(governor);
        ark.forceUpdateInflightAssets(1000 * 10 ** 6);
        assertFalse(ark.isSynced(), "Should be unsynced with inflight");

        // Simulate receiving balance update (clears inflight)
        _simulateRemoteBalanceUpdate(2000 * 10 ** 6);
        assertTrue(ark.isSynced(), "Should be synced after receiving update");
        assertEq(ark.inflightAssets(), 0, "Should clear inflight assets");

        // Wait for sync window to expire
        vm.warp(block.timestamp + ark.SYNC_WINDOW() + 1);
        assertFalse(
            ark.isSynced(),
            "Should be unsynced after sync window expires"
        );
    }

    function testMultipleSyncCycles() public {
        // First cycle
        _simulateRemoteBalanceUpdate(1000 * 10 ** 6);
        assertTrue(ark.isSynced(), "Should be synced after first update");

        // Wait for sync window to expire
        vm.warp(block.timestamp + ark.SYNC_WINDOW() + 1);
        assertFalse(
            ark.isSynced(),
            "Should be unsynced after sync window expires"
        );

        // Second cycle
        _simulateRemoteBalanceUpdate(2000 * 10 ** 6);
        assertTrue(ark.isSynced(), "Should be synced after second update");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _simulateRemoteBalanceUpdate(uint256 balance) internal {
        bytes32 operationId = bytes32(uint256(123));
        bytes32 transferId = ark.latestOutgoingTransferId();

        // Encode the message with balance and transfer ID
        bytes memory message = abi.encode(balance, transferId);

        // Create message params
        BridgeTypes.RelayedMessageParams memory params = BridgeTypes
            .RelayedMessageParams({
                operationId: operationId,
                sourceChainId: TARGET_CHAIN_ID,
                originator: proxy,
                recipient: address(ark),
                message: message
            });

        // Call the message handler through the bridge router
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );
    }

    function _simulateTransferAsset(uint256 balance, uint256 amount) internal {
        bytes32 operationId = bytes32(uint256(456));

        // Encode the message with balance
        bytes memory message = abi.encode(balance);

        // Create transfer params
        BridgeTypes.RelayedTransferParams memory params = BridgeTypes
            .RelayedTransferParams({
                operationId: operationId,
                sourceChainId: TARGET_CHAIN_ID,
                originator: proxy,
                recipient: address(ark),
                asset: address(mockToken),
                amount: amount,
                message: message
            });

        // Call the transfer handler through the bridge router
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            abi.encode(params)
        );
    }

    function _simulateMessageWithTransferId(
        uint256 balance,
        bytes32 transferId
    ) internal {
        bytes32 operationId = bytes32(uint256(789));

        // Encode the message with balance and specific transfer ID
        bytes memory message = abi.encode(balance, transferId);

        // Create message params
        BridgeTypes.RelayedMessageParams memory params = BridgeTypes
            .RelayedMessageParams({
                operationId: operationId,
                sourceChainId: TARGET_CHAIN_ID,
                originator: proxy,
                recipient: address(ark),
                message: message
            });

        // Call the message handler through the bridge router
        vm.prank(address(router));
        ark.receiveOperation(
            BridgeTypes.OperationType.MESSAGE,
            abi.encode(params)
        );
    }
}
