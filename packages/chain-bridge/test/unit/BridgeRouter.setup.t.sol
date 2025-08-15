// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {BridgeRouterTestHelper} from "../helpers/BridgeRouterTestHelper.sol";
import {MockAdapter} from "../mocks/MockAdapter.sol";
import {MockCrossChainReceiver} from "../mocks/MockCrossChainReceiver.sol";

import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title BridgeRouterSetup
 * @notice Reusable fixture that deploys and wires together a BridgeRouter test
 *         environment.  All unit-tests for BridgeRouter can `is` this contract
 *         and simply call `super.setUp()` inside their own `setUp()` method.
 */
contract BridgeRouterSetup is Test {
    /* ────────────────  Core contracts & mocks  ──────────────── */
    BridgeRouterTestHelper public router;
    ProtocolAccessManager public accessManager;
    CrossChainRegistry public registry;

    MockAdapter public mockAdapter; // CURRENT_CHAIN_ID adapter
    MockAdapter public mockAdapterDest; // DEST_CHAIN_ID adapter
    MockAdapter public mockAdapterSource; // SOURCE_CHAIN_ID adapter
    MockCrossChainReceiver public mockReceiver;
    ERC20Mock public token;

    /* ────────────────  Test actors  ──────────────── */
    /// forge-lint: disable-start(screaming-snake-case-const)
    address public constant governor = address(0x1);
    address public constant guardian = address(0x2);
    address public constant user = address(0x3);
    address public constant keeper = address(0x4);
    address public constant executor = address(0x5);
    /// forge-lint: disable-end(screaming-snake-case-const)

    /* ────────────────  Chain / value constants  ──────────────── */
    uint16 public immutable CURRENT_CHAIN_ID = uint16(block.chainid);
    uint16 public constant DEST_CHAIN_ID = 10; // Optimism in tests
    uint16 public constant SOURCE_CHAIN_ID = 111; // Arbitrary test chain
    uint256 public constant DEFAULT_GAS_LIMIT = 500000;

    uint256 public constant INITIAL_ROUTER_BALANCE = 500 ether; // asset tests
    uint256 public constant TRANSFER_AMOUNT = 1000 ether;

    /* -------------------------------------------------------------------------- */
    /*                                  set-up                                    */
    /* -------------------------------------------------------------------------- */

    function setUp() public virtual {
        /* --------- Access manager & registry --------- */
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistry(
            address(accessManager),
            CURRENT_CHAIN_ID
        );

        /* --------- BridgeRouter (test helper) --------- */
        vm.startPrank(governor);

        router = new BridgeRouterTestHelper(
            address(accessManager),
            address(registry)
        );

        /* --------- Mock adapters --------- */
        // Each chain gets its own adapter instance
        mockAdapter = new MockAdapter(
            address(registry),
            address(accessManager)
        ); // CURRENT_CHAIN_ID adapter

        mockAdapterDest = new MockAdapter(
            address(registry),
            address(accessManager)
        ); // DEST_CHAIN_ID adapter

        mockAdapterSource = new MockAdapter(
            address(registry),
            address(accessManager)
        ); // SOURCE_CHAIN_ID adapter

        // Configure supported chains for each adapter
        mockAdapter.setSupportedChain(SOURCE_CHAIN_ID, true);
        mockAdapter.setSupportedChain(DEST_CHAIN_ID, true);
        mockAdapterDest.setSupportedChain(CURRENT_CHAIN_ID, true);
        mockAdapterSource.setSupportedChain(CURRENT_CHAIN_ID, true);

        // Only register the local adapter with the router
        router.registerAdapter(address(mockAdapter));

        /* --------- Registry initialisation --------- */
        registry.initializeBridgeConfiguration(
            address(router),
            DEFAULT_GAS_LIMIT
        );

        // Only register relationships where one end is CURRENT_CHAIN_ID

        // Relationship: CURRENT_CHAIN_ID -> DEST_CHAIN_ID
        registry.registerAdapterPeer(
            address(mockAdapter), // sourceAdapter (local)
            address(mockAdapterDest), // targetAdapter (remote)
            CURRENT_CHAIN_ID, // sourceChainId
            DEST_CHAIN_ID // targetChainId
        );

        // Relationship: DEST_CHAIN_ID -> CURRENT_CHAIN_ID
        registry.registerAdapterPeer(
            address(mockAdapterDest), // sourceAdapter (remote)
            address(mockAdapter), // targetAdapter (local)
            DEST_CHAIN_ID, // sourceChainId
            CURRENT_CHAIN_ID // targetChainId
        );

        // Relationship: SOURCE_CHAIN_ID -> CURRENT_CHAIN_ID
        registry.registerAdapterPeer(
            address(mockAdapterSource), // sourceAdapter (remote)
            address(mockAdapter), // targetAdapter (local)
            SOURCE_CHAIN_ID, // sourceChainId
            CURRENT_CHAIN_ID // targetChainId
        );

        // Relationship: CURRENT_CHAIN_ID -> SOURCE_CHAIN_ID
        registry.registerAdapterPeer(
            address(mockAdapter), // sourceAdapter (local)
            address(mockAdapterSource), // targetAdapter (remote)
            CURRENT_CHAIN_ID, // sourceChainId
            SOURCE_CHAIN_ID // targetChainId
        );

        // Executors / keepers used by various tests
        registry.registerExecutor(keeper);
        registry.registerExecutor(executor);
        registry.registerExecutor(address(mockAdapter));

        /* --------- Roles --------- */
        accessManager.grantGuardianRole(guardian);

        /* --------- Assets & receivers --------- */
        token = new ERC20Mock();
        mockReceiver = new MockCrossChainReceiver();

        // Pre-fund router so deliver-tests can forward assets
        token.mint(address(router), INITIAL_ROUTER_BALANCE);

        // General balances for users / keepers
        token.mint(governor, 10000 ether);
        token.mint(guardian, 10000 ether);
        token.mint(user, 10000 ether);
        token.mint(keeper, 10000 ether);
        token.mint(executor, 10000 ether);

        vm.deal(keeper, 1 ether);
        vm.deal(executor, 1 ether);
        vm.deal(address(mockReceiver), 10 ether);
        vm.deal(address(0x999), 1 ether); // Fund unauthorizedCaller for tests

        vm.stopPrank();

        vm.label(address(mockReceiver), "mockReceiver");
        vm.label(address(mockAdapter), "mockAdapter");
        vm.label(address(mockAdapterDest), "mockAdapterDest");
        vm.label(address(mockAdapterSource), "mockAdapterSource");
        vm.label(address(router), "router");
        vm.label(address(accessManager), "accessManager");
        vm.label(address(registry), "registry");
        vm.label(address(token), "token");
        vm.label(address(keeper), "keeper");
        vm.label(address(executor), "executor");
        vm.label(address(governor), "governor");
        vm.label(address(guardian), "guardian");
        vm.label(address(user), "user");
        vm.label(address(0x999), "0x999");
        vm.label(address(0x123), "0x123");
    }

    function testSkip() public {}
}
