// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainRegistry} from "../src/contracts/CrossChainRegistry.sol";
import {CrossChainArk} from "../src/contracts/arks/CrossChainArk.sol";
import {CrossChainFleetProxy} from "../src/contracts/FleetProxy.sol";
import {ICrossChainRegistry} from "../src/interfaces/ICrossChainRegistry.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {MockBridgeQueue} from "@summerfi/chain-bridge-test/mocks/MockBridgeQueue.sol";
import {MockBridgeRouter} from "@summerfi/chain-bridge-test/mocks/MockBridgeRouter.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ArkParams} from "../src/types/ArkTypes.sol";
import {FleetCommanderMock} from "./mocks/FleetCommanderMock.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {Raft} from "../src/contracts/Raft.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title CrossChainRegistryIntegrationTest
 * @notice Integration test demonstrating the complete registry-based workflow
 */
contract CrossChainRegistryIntegrationTest is Test {
    // Contracts
    CrossChainRegistry public registry;
    CrossChainArk public ark;
    CrossChainFleetProxy public proxy;
    ProtocolAccessManager public accessManager;
    MockBridgeQueue public bridgeQueue;
    MockBridgeRouter public bridgeRouter;
    ERC20Mock public token;
    FleetCommanderMock public fleetCommander;
    ConfigurationManager public configurationManager;
    Raft public raft;

    // Test addresses
    address public governor = address(0x1);
    address public keeper = address(0x2);
    address public testAdmin = address(0x3);

    // Chain IDs
    uint16 public constant SOURCE_CHAIN_ID = 1; // Ethereum
    uint16 public constant TARGET_CHAIN_ID = 42161; // Arbitrum

    function setUp() public {
        // Deploy access manager
        accessManager = new ProtocolAccessManager(testAdmin);

        // Grant roles
        vm.startPrank(testAdmin);
        accessManager.grantGovernorRole(governor);
        accessManager.grantKeeperRole(address(this), keeper);
        vm.stopPrank();

        // Deploy configuration manager and raft
        configurationManager = new ConfigurationManager(address(accessManager));
        raft = new Raft(address(accessManager));

        // Set up configuration manager
        vm.prank(governor);
        configurationManager.setRaft(address(raft));

        // Deploy registry
        registry = new CrossChainRegistry(
            address(accessManager),
            SOURCE_CHAIN_ID
        );

        // Deploy bridge infrastructure
        bridgeQueue = new MockBridgeQueue();
        bridgeRouter = new MockBridgeRouter();

        // Deploy token
        token = new ERC20Mock();

        // Deploy fleet commander mock
        fleetCommander = new FleetCommanderMock(
            address(token),
            address(0),
            PercentageUtils.fromFraction(1, 100)
        );

        // Deploy CrossChainArk
        ArkParams memory arkParams = ArkParams({
            name: "TestCrossChainArk",
            details: "Test CrossChain Ark for registry integration",
            accessManager: address(accessManager),
            configurationManager: address(configurationManager),
            asset: address(token),
            depositCap: type(uint256).max,
            maxRebalanceOutflow: type(uint256).max,
            maxRebalanceInflow: type(uint256).max,
            requiresKeeperData: false,
            maxDepositPercentageOfTVL: PercentageUtils.fromFraction(1, 100)
        });

        ark = new CrossChainArk(
            address(bridgeQueue),
            address(bridgeRouter),
            address(registry),
            TARGET_CHAIN_ID,
            arkParams
        );

        // Deploy FleetProxy
        proxy = new CrossChainFleetProxy(
            address(accessManager),
            address(bridgeRouter),
            address(bridgeQueue),
            address(registry),
            address(fleetCommander)
        );
    }

    function testRegistryIntegrationWorkflow() public {
        // 1. Register the relationship in the registry (simplified call)
        vm.prank(governor);
        registry.registerArkProxy(
            address(ark),
            TARGET_CHAIN_ID,
            address(proxy)
        );

        // 2. Verify the relationship is registered
        assertTrue(registry.isArkRegistered(address(ark)));

        // 3. Verify ark can get proxy from registry
        (address retrievedProxy, uint16 retrievedChainId) = registry
            .getProxyForArk(address(ark));
        assertEq(retrievedProxy, address(proxy));
        assertEq(retrievedChainId, TARGET_CHAIN_ID);

        // 4. Verify proxy can get ark from registry
        address retrievedArk = registry.getArkForProxy(
            SOURCE_CHAIN_ID,
            address(proxy)
        );
        assertEq(retrievedArk, address(ark));

        // 5. Verify the relationship is valid and active
        assertTrue(
            registry.isValidArkProxyPair(
                address(ark),
                TARGET_CHAIN_ID,
                address(proxy)
            )
        );

        // 6. Test that ark uses registry for boarding (mock the internal call)
        // Since _getTargetProxy is internal, we test the public behavior
        // The ark should be able to board without having targetProxy set via the deprecated setter

        // Mint tokens and approve
        token.mint(address(this), 1000);
        token.approve(address(ark), 1000);

        // Grant commander role to this test contract
        vm.prank(governor);
        accessManager.grantCommanderRole(address(ark), address(this));

        // Register as fleet commander
        ark.registerFleetCommander();

        // Board should work using registry lookup
        ark.board(1000, "");

        // Verify the bridge queue received the correct parameters
        assertEq(bridgeQueue.lastDestinationChainId(), TARGET_CHAIN_ID);
        assertEq(bridgeQueue.lastAsset(), address(token));
        assertEq(bridgeQueue.lastAmount(), 1000);
        assertEq(bridgeQueue.lastRecipient(), address(proxy)); // Should use proxy from registry
    }

    function testRegistryStatusManagement() public {
        // Register relationship
        vm.prank(governor);
        registry.registerArkProxy(
            address(ark),
            TARGET_CHAIN_ID,
            address(proxy)
        );

        // Initially active
        assertTrue(
            registry.isValidArkProxyPair(
                address(ark),
                TARGET_CHAIN_ID,
                address(proxy)
            )
        );

        // Deactivate relationship
        vm.prank(governor);
        registry.updateRelationshipStatus(address(ark), false);

        // Should be inactive
        assertFalse(
            registry.isValidArkProxyPair(
                address(ark),
                TARGET_CHAIN_ID,
                address(proxy)
            )
        );

        // But still registered
        assertTrue(registry.isArkRegistered(address(ark)));

        // Reactivate
        vm.prank(governor);
        registry.updateRelationshipStatus(address(ark), true);

        // Should be active again
        assertTrue(
            registry.isValidArkProxyPair(
                address(ark),
                TARGET_CHAIN_ID,
                address(proxy)
            )
        );
    }

    function testRegistryOnlyApproach() public {
        // Test that ark now requires registry registration to work

        // 1. Try to board without registry registration - should fail
        token.mint(address(this), 1000);
        token.approve(address(ark), 1000);

        vm.prank(governor);
        accessManager.grantCommanderRole(address(ark), address(this));

        ark.registerFleetCommander();

        // Should revert because no proxy relationship is registered
        vm.expectRevert(CrossChainArk.NoProxyRelationshipRegistered.selector);
        ark.board(1000, "");

        // 2. Register relationship in registry
        vm.prank(governor);
        registry.registerArkProxy(
            address(ark),
            TARGET_CHAIN_ID,
            address(proxy)
        );

        // 3. Now boarding should work
        ark.board(1000, "");

        // Verify it works with registry
        assertEq(bridgeQueue.lastDestinationChainId(), TARGET_CHAIN_ID);
        assertEq(bridgeQueue.lastAsset(), address(token));
        assertEq(bridgeQueue.lastAmount(), 1000);
        assertEq(bridgeQueue.lastRecipient(), address(proxy));
    }

    function testGetTargetProxyFunction() public {
        // Initially no proxy registered
        assertEq(ark.getTargetProxy(), address(0));

        // Register relationship
        vm.prank(governor);
        registry.registerArkProxy(
            address(ark),
            TARGET_CHAIN_ID,
            address(proxy)
        );

        // Now should return the registered proxy
        assertEq(ark.getTargetProxy(), address(proxy));

        // Unregister
        vm.prank(governor);
        registry.unregisterArkProxy(address(ark));

        // Should return zero address again
        assertEq(ark.getTargetProxy(), address(0));
    }

    function testEnumerationFunctions() public {
        // Initially empty
        assertEq(registry.getRelationshipCount(), 0);
        assertEq(registry.getRegisteredArks().length, 0);

        // Register relationship
        vm.prank(governor);
        registry.registerArkProxy(
            address(ark),
            TARGET_CHAIN_ID,
            address(proxy)
        );

        // Check enumeration
        assertEq(registry.getRelationshipCount(), 1);
        address[] memory arks = registry.getRegisteredArks();
        assertEq(arks.length, 1);
        assertEq(arks[0], address(ark));

        // Unregister and check
        vm.prank(governor);
        registry.unregisterArkProxy(address(ark));

        assertEq(registry.getRelationshipCount(), 0);
        assertEq(registry.getRegisteredArks().length, 0);
    }

    function testQueryFunctions() public {
        // Register relationship
        vm.prank(governor);
        registry.registerArkProxy(
            address(ark),
            TARGET_CHAIN_ID,
            address(proxy)
        );

        // Test all query functions
        (address retrievedProxy, uint16 retrievedChainId) = registry
            .getProxyForArk(address(ark));
        assertEq(retrievedProxy, address(proxy));
        assertEq(retrievedChainId, TARGET_CHAIN_ID);

        address retrievedArk = registry.getArkForProxy(
            SOURCE_CHAIN_ID,
            address(proxy)
        );
        assertEq(retrievedArk, address(ark));

        assertTrue(
            registry.isValidArkProxyPair(
                address(ark),
                TARGET_CHAIN_ID,
                address(proxy)
            )
        );
        assertTrue(registry.isArkRegistered(address(ark)));
    }
}
