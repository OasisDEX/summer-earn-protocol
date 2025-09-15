// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouterSetup} from "./BridgeRouter.setup.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
            router.sweep(address(0), address(this), 1 ether);
        }
    }

    function testSkip() public {}
}

contract BridgeRouterRecoveryTest is BridgeRouterSetup {
    /* ------------------------------------------------------------ */
    /*                    Failure recording & retry                 */
    /* ------------------------------------------------------------ */

    function _makeFailedTransfer(
        bytes32 opId,
        uint256 amount
    ) internal returns (bytes32) {
        // Configure receiver to fail
        mockReceiver.setReceiveSuccess(false);

        // Build transfer payload
        BridgeTypes.RelayedTransferParams memory p = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: user,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                asset: address(token),
                amount: amount,
                message: ""
            });

        bytes memory payload = abi.encode(p);

        // Deliver from registered adapter
        vm.startPrank(address(mockAdapter));
        router.deliver(BridgeTypes.OperationType.TRANSFER_ASSET, payload);
        vm.stopPrank();

        // Recorded as failed
        (bytes32[] memory ids, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids.length, 1);
        assertEq(ids[0], opId);

        return opId;
    }

    function testRecordFailureAndRetry_Succeeds() public {
        bytes32 opId = keccak256("op1");
        uint256 amount = 10 ether;

        _makeFailedTransfer(opId, amount);

        // Now allow receiver to succeed
        mockReceiver.setReceiveSuccess(true);

        // Retry without overrides
        vm.prank(governor);
        router.retryFailedDelivery(opId, "");

        // Failure cleared
        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);

        // Assets delivered
        assertEq(token.balanceOf(address(mockReceiver)), amount);
    }

    function testRetryWithOverridePayload_ChangesAmount() public {
        bytes32 opId = keccak256("op2");
        uint256 originalAmount = 10 ether;
        _makeFailedTransfer(opId, originalAmount);

        // Prepare override with same opId but different amount
        uint256 correctedAmount = 7 ether;
        BridgeTypes.RelayedTransferParams memory corrected = BridgeTypes
            .RelayedTransferParams({
                operationId: opId,
                originator: user,
                sourceChainId: SOURCE_CHAIN_ID,
                recipient: address(mockReceiver),
                asset: address(token),
                amount: correctedAmount,
                message: ""
            });
        bytes memory correctedPayload = abi.encode(corrected);

        // Encode overrideData as tuple (address adapter, bytes payload)
        bytes memory overrideData = abi.encode(address(0), correctedPayload);

        mockReceiver.setReceiveSuccess(true);

        vm.prank(governor);
        router.retryFailedDelivery(opId, overrideData);

        // Failure cleared and corrected amount delivered
        (bytes32[] memory ids2, ) = router.getFailedDeliveryIds(0, 10);
        assertEq(ids2.length, 0);
        assertEq(token.balanceOf(address(mockReceiver)), correctedAmount);
    }

    function testGetFailedDelivery_NonExistentOperationId_RevertsWithFailureRecordNotFound()
        public
    {
        bytes32 nonExistentOpId = keccak256("non-existent-operation");

        vm.expectRevert(IBridgeRouter.FailureRecordNotFound.selector);
        router.getFailedDelivery(nonExistentOpId);
    }

    function testGetFailedDelivery_ExistingOperationId_ReturnsRecord() public {
        // Create a failed operation
        bytes32 opId = _makeFailedTransfer(keccak256("test-op"), 1 ether);

        // Get the failure record
        BridgeRouter.FailedDeliveryRecord memory record = router
            .getFailedDelivery(opId);

        // Verify the record contains expected data
        assertEq(
            uint8(record.operationType),
            uint8(BridgeTypes.OperationType.TRANSFER_ASSET)
        );
        assertEq(record.adapter, address(mockAdapter));
        assertEq(record.sourceChainId, SOURCE_CHAIN_ID);
        assertEq(record.failedAt, block.timestamp);
    }

    /* ------------------------------------------------------------ */
    /*                     Recover assets (moved)                    */
    /* ------------------------------------------------------------ */

    function testRecoverFunds_Success() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;
        uint256 recoverAmount = 2 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            recoverAmount
        );
        router.sweep(address(0), governor, recoverAmount);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterBalance - recoverAmount);
        assertEq(governor.balance, initialGovernorBalance + recoverAmount);
    }

    function testRecoverFunds_AccessControl() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.sweep(address(0), user, 1 ether);
        vm.stopPrank();

        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.sweep(address(0), guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InvalidRecipient() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InvalidParams.selector);
        router.sweep(address(0), address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_InsufficientBalance() public {
        uint256 fundAmount = 1 ether;
        vm.deal(address(router), fundAmount);

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.sweep(address(0), governor, 2 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_TransferFailed() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        RejectETH rejectContract = new RejectETH();

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
        router.sweep(address(0), address(rejectContract), 1 ether);
        vm.stopPrank();
    }

    function testRecoverFunds_ZeroAmount() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialRouterBalance = address(router).balance;
        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(0), governor, 0);
        router.sweep(address(0), governor, 0);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterBalance);
        assertEq(governor.balance, initialGovernorBalance);
    }

    function testRecoverFunds_ExactBalance() public {
        uint256 fundAmount = 3 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            fundAmount
        );
        router.sweep(address(0), governor, fundAmount);
        vm.stopPrank();

        assertEq(address(router).balance, 0);
        assertEq(governor.balance, initialGovernorBalance + fundAmount);
    }

    function testRecoverFunds_ReentrancyProtection() public {
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        ReentrancyAttacker attacker = new ReentrancyAttacker(router);

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
        router.sweep(address(0), address(attacker), 1 ether);
        vm.stopPrank();

        assertEq(attacker.callCount(), 0);
        assertEq(address(router).balance, fundAmount);
    }

    function testRecoverFunds_MultipleRecoveries() public {
        uint256 fundAmount = 10 ether;
        vm.deal(address(router), fundAmount);

        uint256 initialGovernorBalance = governor.balance;

        vm.startPrank(governor);

        uint256 firstAmount = 3 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            firstAmount
        );
        router.sweep(address(0), governor, firstAmount);

        uint256 secondAmount = 2 ether;
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            governor,
            secondAmount
        );
        router.sweep(address(0), governor, secondAmount);

        vm.stopPrank();

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
        uint256 fundAmount = 5 ether;
        vm.deal(address(router), fundAmount);

        address externalAccount = address(0x12345);
        uint256 initialExternalBalance = externalAccount.balance;
        uint256 recoverAmount = 2 ether;

        vm.startPrank(governor);
        vm.expectEmit(true, false, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(
            address(0),
            externalAccount,
            recoverAmount
        );
        router.sweep(address(0), externalAccount, recoverAmount);
        vm.stopPrank();

        assertEq(address(router).balance, fundAmount - recoverAmount);
        assertEq(
            externalAccount.balance,
            initialExternalBalance + recoverAmount
        );
    }

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
        router.sweep(address(0), governor, recoverAmount);
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
        router.sweep(address(token), governor, recoverAmount);
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
        router.sweep(address(0), address(0), 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_AccessControl() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                user
            )
        );
        router.sweep(address(0), user, 1 ether);
        vm.stopPrank();

        vm.startPrank(guardian);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                guardian
            )
        );
        router.sweep(address(token), guardian, 1 ether);
        vm.stopPrank();
    }

    function testRecoverAssets_InsufficientNativeBalance() public {
        vm.deal(address(router), 0.5 ether);
        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.InsufficientBalance.selector);
        router.sweep(address(0), governor, 1 ether);
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
        router.sweep(address(0), governor, 0);

        vm.expectEmit(true, true, false, true);
        emit IBridgeRouter.RouterAssetsRecovered(address(token), governor, 0);
        router.sweep(address(token), governor, 0);
        vm.stopPrank();

        assertEq(address(router).balance, initialRouterEth);
        assertEq(governor.balance, initialGovernorEth);
        assertEq(token.balanceOf(address(router)), initialRouterToken);
        assertEq(token.balanceOf(governor), initialGovernorToken);
    }

    function testRecoverAssets_Native_TransferFailed() public {
        vm.deal(address(router), 1 ether);
        RejectETH rejectContract = new RejectETH();

        vm.startPrank(governor);
        vm.expectRevert(IBridgeRouter.TransferFailed.selector);
        router.sweep(address(0), address(rejectContract), 1 ether);
        vm.stopPrank();
    }
}
