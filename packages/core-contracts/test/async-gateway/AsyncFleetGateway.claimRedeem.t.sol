// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IAsyncFleetGatewayEnums} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayEnums.sol";

contract AsyncFleetGatewayClaimRedeemTest is AsyncFleetGatewayTestBase {
    function setUp() public override {
        super.setUp();
        _mintFleetShares(alice, 100e18);
        assetToken.mint(address(fleetMock), 1_000e6); // exit liquidity for rate changes
    }

    function test_AFG0601_ClaimFullRedeem() public {
        _requestRedeem(alice, 100e18);
        uint256 epoch = _closeAndSettleRedeem();
        uint256 expectedAssets = gateway.maxWithdraw(alice);

        uint256 balBefore = assetToken.balanceOf(alice);
        vm.expectEmit(true, true, true, true);
        emit Withdraw(alice, alice, alice, expectedAssets, 100e18);
        vm.prank(alice);
        uint256 assets = gateway.redeem(100e18, alice, alice);

        assertEq(assets, expectedAssets);
        assertEq(assetToken.balanceOf(alice) - balBefore, expectedAssets);
        assertEq(gateway.balanceOf(alice, gateway.redeemReceiptId(epoch)), 0);
        assertEq(gateway.maxRedeem(alice), 0);
    }

    function test_AFG0602_WithdrawByAssets() public {
        // NOTE: fixture fix — MockFleet.convertToAssets() is
        // shares.mulDiv(assetsPerShare, 1e18); shares here are 18-decimal (100e18) and the mock
        // asset is 6-decimal. To land on the brief's literal 200e6/25e18/150e6 assertions, the
        // rate must be expressed in the asset's own decimals (2e6 = "2 USDC per share"), not
        // 2e18 as originally drafted. 2e18 would settle 100e18 shares into 200e18 assets, which
        // fails the hardcoded assertions below outright (not a rounding nuance — a 1e12 unit
        // mismatch). Asserted values are unchanged from the brief.
        fleetMock.setAssetsPerShare(2e6); // 100e18 shares -> 200e6 assets
        _requestRedeem(alice, 100e18);
        _closeAndSettleRedeem();

        assertEq(gateway.maxWithdraw(alice), 200e6);
        vm.prank(alice);
        uint256 sharesUsed = gateway.withdraw(50e6, alice, alice);
        assertEq(sharesUsed, 25e18);
        assertEq(gateway.maxWithdraw(alice), 150e6);
    }

    function test_AFG0603_FifoAcrossRedeemEpochs() public {
        _requestRedeem(alice, 40e18); // epoch 0 @ 1:1
        _closeAndSettleRedeem();
        fleetMock.setAssetsPerShare(2e18);
        _mintFleetShares(alice, 60e18);
        _requestRedeem(alice, 60e18); // epoch 1 @ 2:1
        _closeAndSettleRedeem();

        // redeem 100e18 shares total → 40e6*(1) rate0 + 60 shares at rate1
        uint256 expected = gateway.redeemRate(0).baseAmount +
            gateway.redeemRate(1).baseAmount;
        vm.prank(alice);
        uint256 assets = gateway.redeem(100e18, alice, alice);
        assertEq(assets, expected);
    }

    function test_AFG0604_OverRedeemReverts() public {
        _requestRedeem(alice, 100e18);
        _closeAndSettleRedeem();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExceededMaxClaim.selector,
                alice,
                101e18,
                100e18
            )
        );
        gateway.redeem(101e18, alice, alice);
    }

    function test_AFG0605_StrangerCannotClaimRedeem() public {
        _requestRedeem(alice, 100e18);
        _closeAndSettleRedeem();
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidOperator.selector, alice, bob)
        );
        gateway.redeem(100e18, bob, alice);
    }

    function test_AFG0606_SettleEmptyRedeemEpochLeavesZeroRate() public {
        uint256 epoch = _closeAndSettleRedeem(); // nobody requested redeem
        assertEq(
            uint8(gateway.redeemEpochState(epoch)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Settled)
        );
        assertEq(gateway.redeemRate(epoch).baseAmount, 0);
    }
}
