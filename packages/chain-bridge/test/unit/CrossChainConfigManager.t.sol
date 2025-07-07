// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainConfigManager} from "../../src/router/CrossChainConfigManager.sol";
import {ICrossChainConfigManager, CrossChainConfigManagerParams} from "../../src/interfaces/ICrossChainConfigManager.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

contract CrossChainConfigManagerTest is Test {
    CrossChainConfigManager public configManager;
    ProtocolAccessManager public accessManager;

    address public governor = address(0x1);
    address public guardian = address(0x2);
    address public user = address(0x3);

    // Mock addresses for testing
    address public mockBridgeQueue = address(0x100);
    address public mockBridgeRouter = address(0x200);
    address public mockCrossChainRegistry = address(0x300);
    address public newMockBridgeQueue = address(0x400);
    address public newMockBridgeRouter = address(0x500);
    address public newMockCrossChainRegistry = address(0x600);

    uint256 public constant DEFAULT_GAS_LIMIT = 200000;
    uint256 public constant NEW_GAS_LIMIT = 300000;

    function setUp() public {
        // Deploy access manager and set up roles
        accessManager = new ProtocolAccessManager(governor);

        vm.prank(governor);
        accessManager.grantGuardianRole(guardian);

        // Deploy CrossChainConfigManager
        configManager = new CrossChainConfigManager(address(accessManager));
    }

    // ---- CONSTRUCTOR TESTS ----

    function testConstructor() public view {
        assertFalse(configManager.initialized());
        assertEq(configManager.bridgeQueue(), address(0));
        assertEq(configManager.bridgeRouter(), address(0));
        assertEq(configManager.crossChainRegistry(), address(0));
        assertEq(configManager.defaultGasLimit(), 0);
    }

    // ---- INITIALIZATION TESTS ----

    function testInitializeCrossChainConfiguration() public {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.startPrank(governor);

        // Expect all events to be emitted
        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.BridgeQueueUpdated(
            address(0),
            mockBridgeQueue
        );

        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.BridgeRouterUpdated(
            address(0),
            mockBridgeRouter
        );

        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.CrossChainRegistryUpdated(
            address(0),
            mockCrossChainRegistry
        );

        vm.expectEmit(false, false, false, true);
        emit ICrossChainConfigManager.DefaultGasLimitUpdated(
            0,
            DEFAULT_GAS_LIMIT
        );

        configManager.initializeCrossChainConfiguration(params);

        // Verify state
        assertTrue(configManager.initialized());
        assertEq(configManager.bridgeQueue(), mockBridgeQueue);
        assertEq(configManager.bridgeRouter(), mockBridgeRouter);
        assertEq(configManager.crossChainRegistry(), mockCrossChainRegistry);
        assertEq(configManager.defaultGasLimit(), DEFAULT_GAS_LIMIT);

        vm.stopPrank();
    }

    function testInitializeCrossChainConfigurationTwice() public {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.startPrank(governor);

        // First initialization should succeed
        configManager.initializeCrossChainConfiguration(params);

        // Second initialization should revert
        vm.expectRevert(
            ICrossChainConfigManager
                .CrossChainConfigManagerAlreadyInitialized
                .selector
        );
        configManager.initializeCrossChainConfiguration(params);

        vm.stopPrank();
    }

    function testInitializeCrossChainConfigurationUnauthorized() public {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        configManager.initializeCrossChainConfiguration(params);

        vm.stopPrank();
    }

    function testInitializeCrossChainConfigurationZeroBridgeQueue() public {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: address(0),
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.AddressZero.selector);
        configManager.initializeCrossChainConfiguration(params);

        vm.stopPrank();
    }

    function testInitializeCrossChainConfigurationZeroBridgeRouter() public {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: address(0),
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.AddressZero.selector);
        configManager.initializeCrossChainConfiguration(params);

        vm.stopPrank();
    }

    function testInitializeCrossChainConfigurationZeroCrossChainRegistry()
        public
    {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: address(0),
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.AddressZero.selector);
        configManager.initializeCrossChainConfiguration(params);

        vm.stopPrank();
    }

    function testInitializeCrossChainConfigurationZeroGasLimit() public {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: 0
            });

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.InvalidGasLimit.selector);
        configManager.initializeCrossChainConfiguration(params);

        vm.stopPrank();
    }

    // ---- SETTER TESTS ----

    function testSetBridgeQueue() public {
        // Initialize first
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.BridgeQueueUpdated(
            mockBridgeQueue,
            newMockBridgeQueue
        );

        configManager.setBridgeQueue(newMockBridgeQueue);

        assertEq(configManager.bridgeQueue(), newMockBridgeQueue);

        vm.stopPrank();
    }

    function testSetBridgeQueueUnauthorized() public {
        _initializeConfigManager();

        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        configManager.setBridgeQueue(newMockBridgeQueue);

        vm.stopPrank();
    }

    function testSetBridgeQueueZeroAddress() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.AddressZero.selector);
        configManager.setBridgeQueue(address(0));

        vm.stopPrank();
    }

    function testSetBridgeRouter() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.BridgeRouterUpdated(
            mockBridgeRouter,
            newMockBridgeRouter
        );

        configManager.setBridgeRouter(newMockBridgeRouter);

        assertEq(configManager.bridgeRouter(), newMockBridgeRouter);

        vm.stopPrank();
    }

    function testSetBridgeRouterUnauthorized() public {
        _initializeConfigManager();

        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        configManager.setBridgeRouter(newMockBridgeRouter);

        vm.stopPrank();
    }

    function testSetBridgeRouterZeroAddress() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.AddressZero.selector);
        configManager.setBridgeRouter(address(0));

        vm.stopPrank();
    }

    function testSetCrossChainRegistry() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.CrossChainRegistryUpdated(
            mockCrossChainRegistry,
            newMockCrossChainRegistry
        );

        configManager.setCrossChainRegistry(newMockCrossChainRegistry);

        assertEq(configManager.crossChainRegistry(), newMockCrossChainRegistry);

        vm.stopPrank();
    }

    function testSetCrossChainRegistryUnauthorized() public {
        _initializeConfigManager();

        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        configManager.setCrossChainRegistry(newMockCrossChainRegistry);

        vm.stopPrank();
    }

    function testSetCrossChainRegistryZeroAddress() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.AddressZero.selector);
        configManager.setCrossChainRegistry(address(0));

        vm.stopPrank();
    }

    function testSetDefaultGasLimit() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectEmit(false, false, false, true);
        emit ICrossChainConfigManager.DefaultGasLimitUpdated(
            DEFAULT_GAS_LIMIT,
            NEW_GAS_LIMIT
        );

        configManager.setDefaultGasLimit(NEW_GAS_LIMIT);

        assertEq(configManager.defaultGasLimit(), NEW_GAS_LIMIT);

        vm.stopPrank();
    }

    function testSetDefaultGasLimitUnauthorized() public {
        _initializeConfigManager();

        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        configManager.setDefaultGasLimit(NEW_GAS_LIMIT);

        vm.stopPrank();
    }

    function testSetDefaultGasLimitZero() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        vm.expectRevert(ICrossChainConfigManager.InvalidGasLimit.selector);
        configManager.setDefaultGasLimit(0);

        vm.stopPrank();
    }

    // ---- GUARDIAN ROLE TESTS ----

    function testGuardianCannotCallSetters() public {
        _initializeConfigManager();

        vm.startPrank(guardian);

        // Guardian cannot set bridge queue
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        configManager.setBridgeQueue(newMockBridgeQueue);

        // Guardian cannot set bridge router
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        configManager.setBridgeRouter(newMockBridgeRouter);

        // Guardian cannot set cross chain registry
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        configManager.setCrossChainRegistry(newMockCrossChainRegistry);

        // Guardian cannot set default gas limit
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        configManager.setDefaultGasLimit(NEW_GAS_LIMIT);

        vm.stopPrank();
    }

    // ---- EDGE CASE TESTS ----

    function testSetSameValue() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        // Setting the same value should still emit event
        vm.expectEmit(true, true, false, true);
        emit ICrossChainConfigManager.BridgeQueueUpdated(
            mockBridgeQueue,
            mockBridgeQueue
        );

        configManager.setBridgeQueue(mockBridgeQueue);

        assertEq(configManager.bridgeQueue(), mockBridgeQueue);

        vm.stopPrank();
    }

    function testMultipleUpdates() public {
        _initializeConfigManager();

        vm.startPrank(governor);

        // First update
        configManager.setBridgeQueue(newMockBridgeQueue);
        assertEq(configManager.bridgeQueue(), newMockBridgeQueue);

        // Second update back to original
        configManager.setBridgeQueue(mockBridgeQueue);
        assertEq(configManager.bridgeQueue(), mockBridgeQueue);

        vm.stopPrank();
    }

    // ---- HELPER FUNCTIONS ----

    function _initializeConfigManager() private {
        CrossChainConfigManagerParams
            memory params = CrossChainConfigManagerParams({
                bridgeQueue: mockBridgeQueue,
                bridgeRouter: mockBridgeRouter,
                crossChainRegistry: mockCrossChainRegistry,
                defaultGasLimit: DEFAULT_GAS_LIMIT
            });

        vm.prank(governor);
        configManager.initializeCrossChainConfiguration(params);
    }
}
