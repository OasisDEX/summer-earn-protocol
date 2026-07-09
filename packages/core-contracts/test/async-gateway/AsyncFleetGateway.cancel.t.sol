// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IAsyncFleetGatewayEnums} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayEnums.sol";

contract AsyncFleetGatewayCancelTest is AsyncFleetGatewayTestBase {
    function test_AFG0701_CancelDepositInOpenEpoch() public {
        _requestDeposit(alice, 100e6);
        uint256 balBefore = assetToken.balanceOf(alice);
        vm.prank(alice);
        gateway.cancelDepositRequest(100e6, alice, alice);
        assertEq(assetToken.balanceOf(alice) - balBefore, 100e6);
        assertEq(gateway.pendingDepositRequest(0, alice), 0);
    }

    function test_AFG0702_CancelAfterCloseReverts() public {
        _requestDeposit(alice, 100e6);
        vm.prank(keeper);
        gateway.closeDepositEpoch();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                0,
                IAsyncFleetGatewayEnums.EpochState.InSettlement,
                IAsyncFleetGatewayEnums.EpochState.Open
            )
        );
        gateway.cancelDepositRequest(100e6, alice, alice);
    }

    function test_AFG0703_CancelRedeemReturnsShares() public {
        _mintFleetShares(alice, 10e18);
        uint256 balBefore = fleetMock.balanceOf(alice);
        _requestRedeem(alice, 10e18);
        vm.prank(alice);
        gateway.cancelRedeemRequest(10e18, alice, alice);
        assertEq(fleetMock.balanceOf(alice), balBefore);
        assertEq(gateway.pendingRedeemRequest(0, alice), 0);
    }

    function test_AFG0704_StrangerCannotCancel() public {
        _requestDeposit(alice, 100e6);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(CallerCannotCancel.selector, bob, alice)
        );
        gateway.cancelDepositRequest(100e6, bob, alice);
    }

    function test_AFG0705_Erc1155ApprovedMayCancel() public {
        _requestDeposit(alice, 100e6);
        vm.prank(alice);
        gateway.setApprovalForAll(bob, true);
        vm.prank(bob);
        gateway.cancelDepositRequest(100e6, alice, alice); // proceeds go to alice
        assertEq(gateway.pendingDepositRequest(0, alice), 0);
    }

    function test_AFG0706_CancelRolledBackEpochSucceeds() public {
        _requestDeposit(alice, 100e6); // epoch 0, Open
        vm.prank(keeper);
        gateway.closeDepositEpoch(); // epoch 0 -> InSettlement, epoch 1 Open
        vm.prank(governor);
        gateway.rollbackDepositEpoch(0); // epoch 0 -> Open (rolled-back past epoch)

        // alice still holds the epoch-0 receipt; a rolled-back Open epoch is cancelable
        uint256 balBefore = assetToken.balanceOf(alice);
        vm.prank(alice);
        gateway.cancelDepositRequest(100e6, alice, alice);
        assertEq(assetToken.balanceOf(alice) - balBefore, 100e6);
        assertEq(gateway.pendingDepositRequest(0, alice), 0);
    }
}
