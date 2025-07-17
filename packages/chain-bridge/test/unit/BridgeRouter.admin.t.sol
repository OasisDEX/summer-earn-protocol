// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";

import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";

// Contract that rejects ETH transfers
contract RejectETH {
    receive() external payable {
        revert("Transfer rejected");
    }

    function testSkip() public {}
}

// Reentrancy attack contract
contract ReentrancyAttacker {
    BridgeRouter public router;
    uint256 public callCount;

    constructor(BridgeRouter _router) {
        router = _router;
    }

    receive() external payable {
        callCount++;
        if (callCount == 1) {
            // Try to reenter
            router.recoverFunds(address(this), 1 ether);
        }
    }

    function testSkip() public {}
}

contract BridgeRouterAdminTest is BridgeRouterSetup {
    // ---- ADMIN FUNCTION TESTS ----

    function testPauseByGovernor() public {
        vm.startPrank(governor);

        // Pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Unpause
        router.unpause();
        assertFalse(router.paused());

        vm.stopPrank();
    }

    function testPauseByGuardian() public {
        vm.startPrank(guardian);

        // Guardian can pause
        assertFalse(router.paused());
        router.pause();
        assertTrue(router.paused());

        // Guardian cannot unpause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.unpause();

        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.startPrank(user);

        // Should revert when non-guardian/governor tries to pause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGuardianOrGovernor.selector,
                user
            )
        );
        router.pause();

        vm.stopPrank();
    }

    function testSendWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        // User attempts to queue (NO VALUE)
        vm.startPrank(user);
        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });

        // Get fee estimate first (for keeper execution)
        (uint256 nativeFee, , address specifiedAdapter) = router.quote(
            DEST_CHAIN_ID,
            address(token),
            TRANSFER_AMOUNT,
            options,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
        // vm.deal(user, nativeFee); // REMOVED: User no longer pays

        // Verify the specified adapter matches what we provided
        assertEq(specifiedAdapter, address(mockAdapter));

        vm.stopPrank(); // User stops queueing

        vm.startPrank(executor);

        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeTransferAssets{value: nativeFee}(
            BridgeTypes.ExecuteTransferParams({
                destinationChainId: DEST_CHAIN_ID,
                asset: address(token),
                amount: TRANSFER_AMOUNT,
                recipient: user,
                originator: user,
                keeper: address(executor),
                options: options
            })
        );

        vm.stopPrank();
    }

    function testReadStateWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });

        vm.stopPrank(); // User stops queueing

        vm.startPrank(executor);

        // Get quote for execution
        (uint256 nativeFee, , ) = router.quote(
            DEST_CHAIN_ID,
            address(0), // No asset
            0, // No amount
            options,
            BridgeTypes.OperationType.READ_STATE
        );

        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeReadState{value: nativeFee}(
            BridgeTypes.ExecuteReadStateParams({
                destinationChainId: DEST_CHAIN_ID,
                destinationContract: address(mockAdapter), // Use mock adapter as target contract
                selector: bytes4(keccak256("test()")), // Example function selector
                readParams: "", // Empty params
                originator: user,
                keeper: address(keeper),
                options: options
            })
        );

        vm.stopPrank();
    }

    function testSendMessageWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.AdapterParams memory adapterParams = BridgeTypes
            .AdapterParams({
                gasLimit: 500000,
                calldataSize: 0,
                msgValue: 0,
                options: ""
            });

        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter), // Explicitly specify adapter
            adapterParams: adapterParams
        });
        vm.stopPrank(); // User stops queueing

        // Attempt to execute the queued operation (e.g., by keeper)
        vm.startPrank(executor);

        // The router's execute call should revert because it's paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                recipient: user, // Send to self for testing
                message: "", // Empty message
                originator: user,
                keeper: address(keeper),
                options: options
            })
        );
        vm.stopPrank();
    }

    // ---- RECOVER FUNDS TESTS ----

    function testRecoverFunds_Success() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Record initial balances
        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;
        uint256 recoverAmount = 2 ether;

        // Governor recovers funds
        vm.startPrank(governor);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterFundsRecovered(governor, recoverAmount);

        router.recoverFunds(governor, recoverAmount);
        vm.stopPrank();

        // Verify balances
        assertEq(address(router).balance, initialRouterBalance - recoverAmount);
        assertEq(governor.balance, initialGovernorBalance + recoverAmount);
    }

    function testRecoverFunds_AccessControl() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Non-governor tries to recover funds
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.recoverFunds(user, 1 ether);
        vm.stopPrank();

        // Guardian tries to recover funds
        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.recoverFunds(guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InvalidRecipient() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Governor tries to recover funds to zero address
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.recoverFunds(address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InsufficientBalance() public {
        // Fund the router contract with a small amount
        uint256 fundAmount = 1 ether;
        vm.deal(address(router), fundAmount);

        // Governor tries to recover more than available
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.recoverFunds(governor, 2 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_TransferFailed() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Deploy a contract that rejects ETH transfers
        RejectETH rejectContract = new RejectETH();

        // Governor tries to recover funds to the reject contract
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
        router.recoverFunds(address(rejectContract), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_ZeroAmount() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Record initial balances
        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;

        // Governor recovers zero amount (should succeed)
        vm.startPrank(governor);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterFundsRecovered(governor, 0);

        router.recoverFunds(governor, 0);
        vm.stopPrank();

        // Verify balances remain unchanged
        assertEq(address(router).balance, initialRouterBalance);
        assertEq(governor.balance, initialGovernorBalance);
    }

    function testRecoverFunds_ExactBalance() public {
        // Fund the router contract
        uint256 fundAmount = 3 ether;
        vm.deal(address(router), fundAmount);

        // Record initial balances
        uint256 initialGovernorBalance = governor.balance;

        // Governor recovers exact amount
        vm.startPrank(governor);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterFundsRecovered(governor, fundAmount);

        router.recoverFunds(governor, fundAmount);
        vm.stopPrank();

        // Verify balances
        assertEq(address(router).balance, 0);
        assertEq(governor.balance, initialGovernorBalance + fundAmount);
    }

    function testRecoverFunds_ReentrancyProtection() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Deploy reentrancy attack contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(router);

        // Governor tries to recover funds to the attacker contract
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.TransferFailed.selector); // Should revert due to reentrancy guard
        router.recoverFunds(address(attacker), 1 ether);
        vm.stopPrank();

        // Verify the attack was prevented
        // reentrancy guard reverted
        assertEq(attacker.callCount(), 0);
        assertEq(address(router).balance, fundAmount);
    }

    function testRecoverFunds_MultipleRecoveries() public {
        // Fund the router contract
        uint256 fundAmount = 10 ether;
        vm.deal(address(router), fundAmount);

        // Record initial balances
        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);

        // First recovery
        uint256 firstAmount = 3 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterFundsRecovered(governor, firstAmount);
        router.recoverFunds(governor, firstAmount);

        // Second recovery
        uint256 secondAmount = 2 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterFundsRecovered(governor, secondAmount);
        router.recoverFunds(governor, secondAmount);

        vm.stopPrank();

        // Verify final balances
        assertEq(
            address(router).balance,
            fundAmount - firstAmount - secondAmount
        );
        assertEq(
            governor.balance,
            initialGovernorBalance + firstAmount + secondAmount
        );
    }

    function testRecoverFunds_ToExternalAccount() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Create external account
        address externalAccount = address(0x12345);
        uint256 initialExternalBalance = externalAccount.balance;
        uint256 recoverAmount = 2 ether;

        // Governor recovers funds to external account
        vm.startPrank(governor);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterFundsRecovered(externalAccount, recoverAmount);

        router.recoverFunds(externalAccount, recoverAmount);
        vm.stopPrank();

        // Verify balances
        assertEq(address(router).balance, fundAmount - recoverAmount);
        assertEq(
            externalAccount.balance,
            initialExternalBalance + recoverAmount
        );
    }
}
