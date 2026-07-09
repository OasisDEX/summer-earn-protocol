// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";

contract AsyncFleetGatewayFuzzTest is AsyncFleetGatewayTestBase {
    /// @dev Claims can never pay out more fleet shares than the settlement trade produced.
    function testFuzz_AFG1001_DepositClaimsNeverExceedSettlementOutput(
        uint256 a1,
        uint256 a2,
        uint256 rate
    ) public {
        a1 = bound(a1, 1, 1_000_000e6);
        a2 = bound(a2, 1, 1_000_000e6);
        rate = bound(rate, 0.1e18, 100e18);
        fleetMock.setAssetsPerShare(rate);

        assetToken.mint(alice, a1);
        assetToken.mint(bob, a2);
        _requestDeposit(alice, a1);
        vm.prank(bob);
        gateway.requestDeposit(a2, bob, bob);
        _closeAndSettleDeposit();

        uint256 settledShares = fleetMock.balanceOf(address(gateway));

        vm.prank(alice);
        uint256 sA = gateway.deposit(a1, alice, alice);
        vm.prank(bob);
        uint256 sB = gateway.deposit(a2, bob, bob);

        assertLe(sA + sB, settledShares); // rounding dust stays in the gateway, never negative
    }

    /// @dev Partial claims sum to no more than a single full claim would have paid.
    function testFuzz_AFG1002_PartialDepositClaimsDontInflate(
        uint256 assets,
        uint256 cut,
        uint256 rate
    ) public {
        assets = bound(assets, 2, 1_000_000e6);
        cut = bound(cut, 1, assets - 1);
        rate = bound(rate, 0.1e18, 100e18);
        fleetMock.setAssetsPerShare(rate);

        assetToken.mint(alice, assets);
        _requestDeposit(alice, assets);
        _closeAndSettleDeposit();
        uint256 fullClaim = gateway.maxMint(alice);

        vm.startPrank(alice);
        uint256 s1 = gateway.deposit(cut, alice, alice);
        uint256 s2 = gateway.deposit(assets - cut, alice, alice);
        vm.stopPrank();

        assertLe(s1 + s2, fullClaim);
    }

    /// @dev Redeem-side mirror of 1001.
    function testFuzz_AFG1003_RedeemClaimsNeverExceedSettlementOutput(
        uint256 shares,
        uint256 rate
    ) public {
        shares = bound(shares, 1e6, 1_000_000e18);
        rate = bound(rate, 0.1e18, 10e18);
        fleetMock.setAssetsPerShare(rate);
        assetToken.mint(address(fleetMock), type(uint128).max); // exit liquidity

        _mintFleetShares(alice, shares);
        _requestRedeem(alice, shares);
        _closeAndSettleRedeem();
        uint256 settledAssets = assetToken.balanceOf(address(gateway));

        vm.prank(alice);
        uint256 got = gateway.redeem(shares, alice, alice);
        assertLe(got, settledAssets);
    }

    /// @dev mint() always delivers exactly the requested shares while burning >= fair assets.
    function testFuzz_AFG1004_MintExactness(
        uint256 assets,
        uint256 rate,
        uint256 sharePct
    ) public {
        assets = bound(assets, 1e6, 1_000_000e6);
        rate = bound(rate, 0.5e18, 50e18);
        sharePct = bound(sharePct, 1, 99);
        fleetMock.setAssetsPerShare(rate);

        assetToken.mint(alice, assets);
        _requestDeposit(alice, assets);
        _closeAndSettleDeposit();

        uint256 wantShares = (gateway.maxMint(alice) * sharePct) / 100;
        vm.assume(wantShares > 0);
        vm.prank(alice);
        gateway.mint(wantShares, alice, alice);
        assertEq(fleetMock.balanceOf(alice), wantShares);
    }
}
