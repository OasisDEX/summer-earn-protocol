// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {CrossChainConfigManaged} from "../../../src/contracts/CrossChainConfigManaged.sol";
import {ICrossChainConfigManaged} from "../../../src/interfaces/ICrossChainConfigManaged.sol";
import {MockCrossChainRegistry} from "../../mocks/MockCrossChainRegistry.sol";

contract CrossChainConfigManagedHelper is CrossChainConfigManaged {
    constructor(address registry) CrossChainConfigManaged(registry) {}

    function onlyRouterPing() external onlyRouter {}

    function onlyExecutorPing() external onlyAuthorizedExecutor {}
}

contract CrossChainConfigManagedTest is Test {
    MockCrossChainRegistry private registry;
    CrossChainConfigManagedHelper private helper;

    address private router = address(0xBEEF);
    address private executor = address(0xE1);

    function setUp() public {
        registry = new MockCrossChainRegistry();
        registry.setBridgeRouter(router);
        helper = new CrossChainConfigManagedHelper(address(registry));
    }

    function test_constructor_zero_registry_reverts() public {
        vm.expectRevert(
            CrossChainConfigManaged.CrossChainRegistryZeroAddress.selector
        );
        new CrossChainConfigManagedHelper(address(0));
    }

    function test_bridgeRouter_reads_from_registry() public view {
        assertEq(helper.bridgeRouter(), router);
    }

    function test_crossChainRegistry_returns_address() public view {
        assertEq(helper.crossChainRegistry(), address(registry));
    }

    function test_isExecutor_false_by_default() public view {
        assertFalse(helper.isExecutor(executor));
    }

    function test_isExecutor_true_when_registered() public {
        registry.registerExecutor(executor);
        assertTrue(helper.isExecutor(executor));
    }

    function test_onlyRouter_allows_router() public {
        vm.prank(router);
        helper.onlyRouterPing();
    }

    function test_onlyRouter_reverts_for_non_router() public {
        vm.expectRevert(ICrossChainConfigManaged.OnlyBridgeRouter.selector);
        helper.onlyRouterPing();
    }

    function test_onlyAuthorizedExecutor_allows_registered_executor() public {
        registry.registerExecutor(executor);
        vm.prank(executor);
        helper.onlyExecutorPing();
    }

    function test_onlyAuthorizedExecutor_reverts_for_unregistered() public {
        vm.expectRevert(
            ICrossChainConfigManaged.OnlyAuthorizedExecutor.selector
        );
        helper.onlyExecutorPing();
    }
}
