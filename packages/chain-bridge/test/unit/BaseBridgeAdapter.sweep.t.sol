// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {IBaseBridgeAdapterEvents} from "../../src/interfaces/IBaseBridgeAdapterEvents.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {CrossChainRegistry} from "../../src/contracts/CrossChainRegistry.sol";
import {Errors} from "@openzeppelin/contracts/utils/Errors.sol";
import {Test} from "forge-std/Test.sol";

contract MinimalAdapter is BaseBridgeAdapter {
    constructor(
        address _registry,
        address _accessManager
    ) BaseBridgeAdapter(_registry, _accessManager) {}
}

// Contract that rejects ETH transfers for testing
contract RejectETH {
    receive() external payable {
        revert("Transfer rejected");
    }
}

// Contract that accepts ETH transfers for testing
contract AcceptETH {
    receive() external payable {
        // Accept ETH transfers
    }
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
        registry = new CrossChainRegistry(address(accessManager));
        adapter = new MinimalAdapter(address(registry), address(accessManager));
        vm.stopPrank();
    }

    // ============ ERC20 Token Tests ============

    function testSweep_ERC20_ByGovernor_Succeeds() public {
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

    function testSweep_ERC20_Reverts_WhenUnauthorized() public {
        token.mint(address(adapter), 1 ether);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        adapter.sweep(address(token), address(0xBEEF), 1 ether);
    }

    function testSweep_ERC20_Reverts_WhenInsufficientBalance() public {
        // Adapter has 0 tokens initially
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InsufficientBalance.selector
            )
        );
        adapter.sweep(address(token), address(0xBEEF), 1 ether);
    }

    function testSweep_ERC20_Reverts_WhenRecipientZero() public {
        token.mint(address(adapter), 1 ether);
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidParams.selector
            )
        );
        adapter.sweep(address(token), address(0), 1);
    }

    // ============ Native ETH Tests ============

    function testSweep_Native_ByGovernor_Succeeds() public {
        // Fund adapter with native ETH
        vm.deal(address(adapter), 5 ether);

        address to = address(0xBEEF);
        uint256 amount = 2 ether;
        uint256 toBalanceBefore = to.balance;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(0), amount, to);

        vm.prank(governor);
        adapter.sweep(address(0), to, amount);

        assertEq(to.balance, toBalanceBefore + amount);
        assertEq(address(adapter).balance, 3 ether);
    }

    function testSweep_Native_FullBalance_Succeeds() public {
        // Fund adapter with native ETH
        uint256 adapterBalance = 3.5 ether;
        vm.deal(address(adapter), adapterBalance);

        address to = address(0xBEEF);
        uint256 toBalanceBefore = to.balance;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(0), adapterBalance, to);

        vm.prank(governor);
        adapter.sweep(address(0), to, adapterBalance);

        assertEq(to.balance, toBalanceBefore + adapterBalance);
        assertEq(address(adapter).balance, 0);
    }

    function testSweep_Native_Reverts_WhenUnauthorized() public {
        vm.deal(address(adapter), 1 ether);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        adapter.sweep(address(0), address(0xBEEF), 1 ether);
    }

    function testSweep_Native_Reverts_WhenInsufficientBalance() public {
        // Adapter has 0 ETH initially
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InsufficientBalance.selector
            )
        );
        adapter.sweep(address(0), address(0xBEEF), 1 ether);
    }

    function testSweep_Native_Reverts_WhenRecipientZero() public {
        vm.deal(address(adapter), 1 ether);
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBaseBridgeAdapterErrors.InvalidParams.selector
            )
        );
        adapter.sweep(address(0), address(0), 1 ether);
    }

    function testSweep_Native_Reverts_WhenTransferFails() public {
        vm.deal(address(adapter), 1 ether);

        RejectETH rejectContract = new RejectETH();

        // Expect SweepFailed event and no revert
        vm.expectEmit(true, false, false, true);
        emit IBaseBridgeAdapterEvents.SweepFailed(
            address(rejectContract),
            1 ether
        );
        vm.prank(governor);
        adapter.sweep(address(0), address(rejectContract), 1 ether);

        // Balance should remain as transfer failed silently
        assertEq(address(adapter).balance, 1 ether);
        assertEq(address(rejectContract).balance, 0);
    }

    function testSweep_Native_ZeroAmount_EmitsEventOnly() public {
        vm.deal(address(adapter), 1 ether);
        address to = address(0xBEEF);
        uint256 toBalanceBefore = to.balance;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(0), 0, to);

        vm.prank(governor);
        adapter.sweep(address(0), to, 0);

        assertEq(to.balance, toBalanceBefore);
        assertEq(address(adapter).balance, 1 ether);
    }

    // ============ Edge Cases ============

    function testSweep_BothTokenTypes_Succeeds() public {
        // Fund adapter with both ERC20 and native ETH
        token.mint(address(adapter), 3 ether);
        vm.deal(address(adapter), 2 ether);

        address to = address(0xBEEF);
        uint256 toTokenBalanceBefore = token.balanceOf(to);
        uint256 toETHBalanceBefore = to.balance;

        // Sweep ERC20 first
        vm.prank(governor);
        adapter.sweep(address(token), to, 1.5 ether);

        // Then sweep native ETH
        vm.prank(governor);
        adapter.sweep(address(0), to, 1 ether);

        assertEq(token.balanceOf(to), toTokenBalanceBefore + 1.5 ether);
        assertEq(to.balance, toETHBalanceBefore + 1 ether);
        assertEq(token.balanceOf(address(adapter)), 1.5 ether);
        assertEq(address(adapter).balance, 1 ether);
    }

    function testSweep_Native_ToContract_Succeeds() public {
        vm.deal(address(adapter), 1 ether);

        // Create a contract that can receive ETH
        address payable contractAddr = payable(address(new AcceptETH()));
        uint256 contractBalanceBefore = contractAddr.balance;

        vm.expectEmit(true, true, false, true);
        emit TokensRecovered(address(0), 0.5 ether, contractAddr);

        vm.prank(governor);
        adapter.sweep(address(0), contractAddr, 0.5 ether);

        assertEq(contractAddr.balance, contractBalanceBefore + 0.5 ether);
    }
}
