// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IERC7540Redeem} from "../../src/interfaces/async-gateway/IERC7540.sol";
import {IAsyncFleetGatewayEnums} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayEnums.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";

contract AsyncFleetGatewayRequestRedeemTest is AsyncFleetGatewayTestBase {
    function setUp() public override {
        super.setUp();
        _mintFleetShares(alice, 100e18);
    }

    function test_AFG0501_RequestRedeemHappyPath() public {
        // approve up front so the RedeemRequest emission below is the very next log
        // (the `_requestRedeem` helper interleaves its own Approval log, breaking expectEmit)
        vm.prank(alice);
        fleetMock.approve(address(gateway), 100e18);

        vm.expectEmit(true, true, true, true);
        emit IERC7540Redeem.RedeemRequest(alice, alice, 0, alice, 100e18);
        vm.prank(alice);
        uint256 id = gateway.requestRedeem(100e18, alice, alice);
        assertEq(id, 0);
        assertEq(fleetMock.balanceOf(address(gateway)), 100e18);
        assertEq(gateway.balanceOf(alice, gateway.redeemReceiptId(0)), 100e18);
        assertEq(gateway.pendingRedeemRequest(0, alice), 100e18);
    }

    function test_AFG0502_RequestRedeemRequiresOwnerOrOperator() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidOperator.selector, alice, bob)
        );
        gateway.requestRedeem(1e18, alice, alice);
    }

    function test_AFG0503_SettleRedeemsFromFleetAndSnapshotsRate() public {
        fleetMock.setAssetsPerShare(2e18);
        _requestRedeem(alice, 100e18);
        // fund the fleet so it can pay out 2 assets per share: 100e18 shares * 2e18 rate = 200e18
        // assets required, so 1_000e6 (brief's figure) is ~200x too small — bump to cover it.
        assetToken.mint(address(fleetMock), 1_000e18);
        uint256 epoch = _closeAndSettleRedeem();

        uint256 expectedAssets = fleetMock.convertToAssets(100e18);
        assertEq(assetToken.balanceOf(address(gateway)), expectedAssets);
        assertEq(fleetMock.balanceOf(address(gateway)), 0);
        Price memory rate = gateway.redeemRate(epoch);
        assertEq(rate.baseAmount, expectedAssets);
        assertEq(rate.quoteAmount, 100e18);
        assertEq(gateway.claimableRedeemRequest(epoch, alice), 100e18);
        assertEq(gateway.pendingRedeemRequest(epoch, alice), 0);
    }

    function test_AFG0504_RedeemLifecycleGuards() public {
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                0,
                IAsyncFleetGatewayEnums.EpochState.Open,
                IAsyncFleetGatewayEnums.EpochState.InSettlement
            )
        );
        gateway.settleRedeemEpoch(0);

        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(CannotRetryCurrentEpoch.selector, 0, 0)
        );
        gateway.retryRedeemEpoch(0);
    }

    function test_AFG0505_RedeemRollbackRetry() public {
        _requestRedeem(alice, 10e18);
        vm.prank(keeper);
        gateway.closeRedeemEpoch();
        vm.prank(governor);
        gateway.rollbackRedeemEpoch(0);
        vm.prank(keeper);
        gateway.retryRedeemEpoch(0);
        vm.prank(keeper);
        gateway.settleRedeemEpoch(0);
        assertEq(
            uint8(gateway.redeemEpochState(0)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Settled)
        );
    }

    function test_AFG0506_RollbackRedeemRequiresInSettlement() public {
        // epoch 0 is Open (never closed) — rollback must reject it
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                0,
                IAsyncFleetGatewayEnums.EpochState.Open,
                IAsyncFleetGatewayEnums.EpochState.InSettlement
            )
        );
        gateway.rollbackRedeemEpoch(0);
    }

    function test_AFG0507_RetryRedeemRequiresOpen() public {
        _mintFleetShares(alice, 10e18);
        _requestRedeem(alice, 10e18);
        uint256 epoch = _closeAndSettleRedeem(); // epoch 0 now Settled, current is 1
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                epoch,
                IAsyncFleetGatewayEnums.EpochState.Settled,
                IAsyncFleetGatewayEnums.EpochState.Open
            )
        );
        gateway.retryRedeemEpoch(epoch);
    }

    function test_AFG0508_OnlyKeeperAndGovernorGatesRedeem() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotKeeper.selector,
                alice
            )
        );
        gateway.closeRedeemEpoch();

        _requestRedeem(alice, 10e18);
        vm.prank(keeper);
        gateway.closeRedeemEpoch();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                alice
            )
        );
        gateway.rollbackRedeemEpoch(0);
    }
}
