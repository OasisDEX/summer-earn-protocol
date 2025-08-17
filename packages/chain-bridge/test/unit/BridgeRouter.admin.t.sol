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
            router.recoverAssets(address(0), address(this), 1 ether);
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
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
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
                target: user,
                originator: user,
                refundAddress: address(executor),
                message: ""
            }),
            options
        );

        vm.stopPrank();
    }

    function testReadStateWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
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
                target: address(mockAdapter), // Use mock adapter as target contract
                selector: bytes4(keccak256("test()")), // Example function selector
                readParams: "", // Empty params
                originator: user,
                refundAddress: address(keeper)
            }),
            options
        );

        vm.stopPrank();
    }

    function testSendMessageWhenPaused() public {
        // Pause the router
        vm.prank(governor);
        router.pause();

        vm.startPrank(user);

        // Create bridge options
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(mockAdapter),
            gasLimit: 500000,
            calldataSize: 0,
            msgValue: 0,
            options: ""
        });

        vm.stopPrank(); // User stops queueing

        // Attempt to execute the queued operation (e.g., by keeper)
        vm.startPrank(executor);

        // The router's execute call should revert because it's paused
        vm.expectRevert(IBridgeRouter.Paused.selector);
        router.executeSendMessage(
            BridgeTypes.ExecuteSendMessageParams({
                destinationChainId: DEST_CHAIN_ID,
                target: user, // Send to self for testing
                message: "", // Empty message
                originator: user,
                refundAddress: address(keeper)
            }),
            options
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
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            recoverAmount
        );

        router.recoverAssets(address(0), governor, recoverAmount);
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
        router.recoverAssets(address(0), user, 1 ether);
        vm.stopPrank();

        // Guardian tries to recover funds
        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.recoverAssets(address(0), guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InvalidRecipient() public {
        // Fund the router contract
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        // Governor tries to recover funds to zero address
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.recoverAssets(address(0), address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InsufficientBalance() public {
        // Fund the router contract with a small amount
        uint256 fundAmount = 1 ether;
        vm.deal(address(router), fundAmount);

        // Governor tries to recover more than available
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.recoverAssets(address(0), governor, 2 ether);
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
        router.recoverAssets(address(0), address(rejectContract), 1 ether);
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
        emit IBridgeRouter.RouterAssetsRecovered(address(0), governor, 0);

        router.recoverAssets(address(0), governor, 0);
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
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            fundAmount
        );

        router.recoverAssets(address(0), governor, fundAmount);
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
        router.recoverAssets(address(0), address(attacker), 1 ether);
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
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            firstAmount
        );
        router.recoverAssets(address(0), governor, firstAmount);

        // Second recovery
        uint256 secondAmount = 2 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            secondAmount
        );
        router.recoverAssets(address(0), governor, secondAmount);

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
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            externalAccount,
            recoverAmount
        );

        router.recoverAssets(address(0), externalAccount, recoverAmount);
        vm.stopPrank();

        // Verify balances
        assertEq(address(router).balance, fundAmount - recoverAmount);
        assertEq(
            externalAccount.balance,
            initialExternalBalance + recoverAmount
        );
    }

    // ---- NEW: RECOVER ASSETS (combined) TESTS ----

    function testRecoverAssets_Native_Success() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;
        uint256 recoverAmount = 2 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            recoverAmount
        );
        router.recoverAssets(address(0), governor, recoverAmount);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterBalance - recoverAmount);
        assertEq(governor.balance, initialGovernorBalance + recoverAmount);
    }

    function testRecoverAssets_ERC20_Success() public {
        uint256 initialRouterToken = token.balanceOf(address(router));
        uint256 initialGovernorToken = token.balanceOf(governor);
        uint256 recoverAmount = 100 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(token),
            governor,
            recoverAmount
        );
        router.recoverAssets(address(token), governor, recoverAmount);
        vm.stopPrank();

        assertEq(
            token.balanceOf(address(router)),
            initialRouterToken - recoverAmount
        );
        assertEq(
            token.balanceOf(governor),
            initialGovernorToken + recoverAmount
        );
    }

    function testRecoverAssets_InvalidRecipient() public {
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.recoverAssets(address(0), address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_AccessControl() public {
        // Native
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.recoverAssets(address(0), user, 1 ether);
        vm.stopPrank();

        // ERC20
        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.recoverAssets(address(token), guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_InsufficientNativeBalance() public {
        vm.deal(address(router), 0.5 ether);
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.recoverAssets(address(0), governor, 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_ZeroAmount_NativeAndERC20() public {
        uint256 initialRouterEth = address(router).balance;
        uint256 initialGovernorEth = governor.balance;
        uint256 initialRouterToken = token.balanceOf(address(router));
        uint256 initialGovernorToken = token.balanceOf(governor);

        vm.startPrank(governor);
        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(0), governor, 0);
        router.recoverAssets(address(0), governor, 0);

        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(token), governor, 0);
        router.recoverAssets(address(token), governor, 0);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterEth);
        assertEq(governor.balance, initialGovernorEth);
        assertEq(token.balanceOf(address(router)), initialRouterToken);
        assertEq(token.balanceOf(governor), initialGovernorToken);
    }

    function testRecoverAssets_Native_TransferFailed() public {
        // Fund router
        vm.deal(address(router), 1 ether);
        // Recipient rejects ETH
        RejectETH rejectContract = new RejectETH();

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
        router.recoverAssets(address(0), address(rejectContract), 1 ether);
        vm.stopPrank();
    }
}
