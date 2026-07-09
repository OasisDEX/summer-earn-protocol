// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";

/// @notice Coverage-closing wave for the AsyncFleetGateway POC: the 2-arg `mint` overload,
///         multi-epoch FIFO for `mint`/`withdraw` (parity with the already-covered
///         `deposit`/`redeem` FIFO cases), and the claim-side `ZeroAmount` guards.
contract AsyncFleetGatewayCoverageTest is AsyncFleetGatewayTestBase {
    function test_AFG1101_TwoArgMintClaimsFromSender() public {
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();

        uint256 wantShares = gateway.maxMint(alice);
        uint256 balBefore = fleetMock.balanceOf(alice);

        vm.prank(alice);
        gateway.mint(wantShares, alice);

        assertEq(fleetMock.balanceOf(alice) - balBefore, wantShares);
        assertEq(gateway.maxMint(alice), 0);
    }

    function test_AFG1102_MintFifoAcrossEpochs() public {
        // epoch 0 at economic 1:1 (1 USDC per whole 18-decimal share)
        fleetMock.setAssetsPerShare(1e6);
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();
        // epoch 1 at 2 USDC per whole share
        fleetMock.setAssetsPerShare(2e6);
        _requestDeposit(alice, 100e6);
        _closeAndSettleDeposit();

        uint256 sharesE0 = gateway.depositRate(0).baseAmount; // shares settled for the 100e6 epoch-0 deposit
        uint256 sharesE1 = gateway.depositRate(1).baseAmount; // shares settled for the 100e6 epoch-1 deposit
        assertGt(sharesE0, sharesE1); // rate really differs

        // Claim epoch 0 in full plus half of epoch 1's shares — FIFO must drain epoch 0 to zero
        // before touching epoch 1 at all.
        uint256 sliceE1 = sharesE1 / 2;
        uint256 wantShares = sharesE0 + sliceE1;

        uint256 balBefore = fleetMock.balanceOf(alice);
        vm.prank(alice);
        gateway.mint(wantShares, alice, alice);

        assertEq(fleetMock.balanceOf(alice) - balBefore, wantShares);
        assertEq(gateway.claimableDepositRequest(0, alice), 0);
        assertGt(gateway.claimableDepositRequest(1, alice), 0);
    }

    function test_AFG1103_WithdrawFifoAcrossEpochs() public {
        assetToken.mint(address(fleetMock), 1_000e6); // exit liquidity for rate changes

        uint256 redeemSharesE0 = 40e18;
        uint256 redeemSharesE1 = 60e18;

        // epoch 0 at economic 1:1
        fleetMock.setAssetsPerShare(1e6);
        _mintFleetShares(alice, redeemSharesE0);
        _requestRedeem(alice, redeemSharesE0);
        _closeAndSettleRedeem();

        // epoch 1 at 2 USDC per whole share
        fleetMock.setAssetsPerShare(2e6);
        _mintFleetShares(alice, redeemSharesE1);
        _requestRedeem(alice, redeemSharesE1);
        _closeAndSettleRedeem();

        Price memory rate0 = gateway.redeemRate(0);
        Price memory rate1 = gateway.redeemRate(1);
        uint256 assetsE0 = rate0.baseAmount; // assets settled for the 40e18 epoch-0 redeem
        uint256 assetsE1 = rate1.baseAmount; // assets settled for the 60e18 epoch-1 redeem
        assertGt(assetsE1, assetsE0); // rate really differs

        // Withdraw exactly epoch 0's full asset payout plus half of epoch 1's — FIFO must drain
        // epoch 0 to zero before touching epoch 1 at all.
        uint256 sliceE1 = assetsE1 / 2;
        uint256 withdrawAmount = assetsE0 + sliceE1;
        uint256 expectedShares = redeemSharesE0 +
            Math.mulDiv(
                sliceE1,
                rate1.quoteAmount,
                rate1.baseAmount,
                Math.Rounding.Ceil
            );

        uint256 balBefore = assetToken.balanceOf(alice);
        vm.prank(alice);
        uint256 sharesUsed = gateway.withdraw(withdrawAmount, alice, alice);

        assertEq(assetToken.balanceOf(alice) - balBefore, withdrawAmount);
        assertEq(sharesUsed, expectedShares);
        assertEq(gateway.claimableRedeemRequest(0, alice), 0);
        assertGt(gateway.claimableRedeemRequest(1, alice), 0);
    }

    function test_AFG1104_ClaimVerbsRejectZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        gateway.deposit(0, alice, alice);

        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        gateway.mint(0, alice, alice);

        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        gateway.redeem(0, alice, alice);

        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        gateway.withdraw(0, alice, alice);
    }
}
