// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {Test} from "forge-std/Test.sol";

contract MinimalAdapter is BaseBridgeAdapter {
    constructor(
        address _registry,
        address _accessManager
    ) BaseBridgeAdapter(_registry, _accessManager) {}
}

contract BaseBridgeAdapterSweepTest is Test {
    address public governor = address(0xA11CE);
    address public user = address(0xB0B);
    ERC20Mock public token;
    ProtocolAccessManager public accessManager;
    CrossChainRegistry public registry;
    MinimalAdapter public adapter;

    event TokensRecovered(
        address indexed asset,
        uint256 amount,
        address indexed recipient
    );

    function setUp() public {
        vm.startPrank(governor);
        token = new ERC20Mock();
        accessManager = new ProtocolAccessManager(governor);
        registry = new CrossChainRegistry(address(accessManager), 31337);
        adapter = new MinimalAdapter(address(registry), address(accessManager));
        vm.stopPrank();
    }

    function testSweepByGovernor() public {
        // Fund adapter with tokens
        token.mint(address(adapter), 5 ether);

        address to = address(0xBEEF);
        uint256 amount = 2 ether;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(token), amount, to);

        vm.prank(governor);
        adapter.sweep(address(token), to, amount);

        assertEq(token.balanceOf(to), amount);
    }

    function testSweepUnauthorizedReverts() public {
        token.mint(address(adapter), 1 ether);
        vm.prank(user);
        vm.expectRevert();
        adapter.sweep(address(token), address(0xBEEF), 1 ether);
    }

    function testSweepInsufficientBalanceReverts() public {
        // Adapter has 0 tokens initially
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        adapter.sweep(address(token), address(0xBEEF), 1 ether);
    }

    function testSweepZeroRecipientReverts() public {
        token.mint(address(adapter), 1 ether);
        vm.prank(governor);
        vm.expectRevert();
        adapter.sweep(address(token), address(0), 1);
    }
}
