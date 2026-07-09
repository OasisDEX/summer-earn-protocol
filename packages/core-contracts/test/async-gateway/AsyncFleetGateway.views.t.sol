// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";

contract AsyncFleetGatewayViewsTest is AsyncFleetGatewayTestBase {
    function test_AFG0801_PreviewsRevert() public {
        vm.expectRevert(AsyncFlowPreviewUnsupported.selector);
        gateway.previewDeposit(1e6);
        vm.expectRevert(AsyncFlowPreviewUnsupported.selector);
        gateway.previewMint(1e18);
        vm.expectRevert(AsyncFlowPreviewUnsupported.selector);
        gateway.previewWithdraw(1e6);
        vm.expectRevert(AsyncFlowPreviewUnsupported.selector);
        gateway.previewRedeem(1e18);
    }

    function test_AFG0802_ConvertProxiesFleet() public {
        fleetMock.setAssetsPerShare(4e18);
        assertEq(gateway.convertToShares(8e6), fleetMock.convertToShares(8e6));
        assertEq(
            gateway.convertToAssets(2e18),
            fleetMock.convertToAssets(2e18)
        );
    }

    function test_AFG0803_TotalAssetsTracksHeldAssets() public {
        _requestDeposit(alice, 100e6);
        assertEq(gateway.totalAssets(), 100e6);
        _closeAndSettleDeposit();
        assertEq(gateway.totalAssets(), 0); // assets moved into the fleet at settlement
    }

    function test_AFG0804_MaxViewsZeroForStranger() public view {
        assertEq(gateway.maxDeposit(bob), 0);
        assertEq(gateway.maxMint(bob), 0);
        assertEq(gateway.maxWithdraw(bob), 0);
        assertEq(gateway.maxRedeem(bob), 0);
    }
}
