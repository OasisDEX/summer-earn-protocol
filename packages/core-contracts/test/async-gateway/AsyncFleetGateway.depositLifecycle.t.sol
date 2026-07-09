// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AsyncFleetGatewayTestBase} from "./AsyncFleetGatewayTestBase.sol";
import {IAsyncFleetGatewayEnums} from "../../src/interfaces/async-gateway/IAsyncFleetGatewayEnums.sol";
import {IAccessControlErrors} from "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {Price} from "@summerfi/price-solidity/contracts/PriceUtils.sol";

contract AsyncFleetGatewayDepositLifecycleTest is AsyncFleetGatewayTestBase {
    function test_AFG0301_SettleDepositsIntoFleetAndSnapshotsRate() public {
        fleetMock.setAssetsPerShare(2e18); // 1 share = 2 assets → 100e6 assets = 50e6 shares... (18-dec shares)
        _requestDeposit(alice, 100e6);
        uint256 epoch = _closeAndSettleDeposit();

        assertEq(
            uint8(gateway.depositEpochState(epoch)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Settled)
        );
        uint256 expectedShares = fleetMock.convertToShares(100e6);
        assertEq(fleetMock.balanceOf(address(gateway)), expectedShares);
        assertEq(assetToken.balanceOf(address(gateway)), 0);
        Price memory rate = gateway.depositRate(epoch);
        assertEq(rate.baseAmount, expectedShares);
        assertEq(rate.quoteAmount, 100e6);
        assertEq(gateway.pendingDepositRequest(epoch, alice), 0);
        assertEq(gateway.claimableDepositRequest(epoch, alice), 100e6);
    }

    function test_AFG0302_SettleEmptyEpochLeavesZeroRate() public {
        uint256 epoch = _closeAndSettleDeposit(); // nobody deposited
        assertEq(
            uint8(gateway.depositEpochState(epoch)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Settled)
        );
        assertEq(gateway.depositRate(epoch).baseAmount, 0);
    }

    function test_AFG0303_SettleRequiresInSettlement() public {
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                0,
                IAsyncFleetGatewayEnums.EpochState.Open,
                IAsyncFleetGatewayEnums.EpochState.InSettlement
            )
        );
        gateway.settleDepositEpoch(0);
    }

    function test_AFG0304_SettleTwiceReverts() public {
        _requestDeposit(alice, 10e6);
        uint256 epoch = _closeAndSettleDeposit();
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                epoch,
                IAsyncFleetGatewayEnums.EpochState.Settled,
                IAsyncFleetGatewayEnums.EpochState.InSettlement
            )
        );
        gateway.settleDepositEpoch(epoch);
    }

    function test_AFG0305_RollbackThenRetry() public {
        _requestDeposit(alice, 10e6);
        vm.prank(keeper);
        gateway.closeDepositEpoch();

        vm.prank(governor);
        gateway.rollbackDepositEpoch(0);
        assertEq(
            uint8(gateway.depositEpochState(0)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Open)
        );

        vm.prank(keeper);
        gateway.retryDepositEpoch(0);
        assertEq(
            uint8(gateway.depositEpochState(0)),
            uint8(IAsyncFleetGatewayEnums.EpochState.InSettlement)
        );

        vm.prank(keeper);
        gateway.settleDepositEpoch(0);
        assertEq(
            uint8(gateway.depositEpochState(0)),
            uint8(IAsyncFleetGatewayEnums.EpochState.Settled)
        );
    }

    function test_AFG0306_RetryCurrentEpochReverts() public {
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(CannotRetryCurrentEpoch.selector, 0, 0)
        );
        gateway.retryDepositEpoch(0);
    }

    function test_AFG0307_OnlyKeeperAndGovernorGates() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotKeeper.selector,
                alice
            )
        );
        gateway.closeDepositEpoch();

        _requestDeposit(alice, 10e6);
        vm.prank(keeper);
        gateway.closeDepositEpoch();

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlErrors.CallerIsNotGovernor.selector,
                alice
            )
        );
        gateway.rollbackDepositEpoch(0);
    }

    function test_AFG0308_RollbackRequiresInSettlement() public {
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
        gateway.rollbackDepositEpoch(0);
    }

    function test_AFG0309_RetryRequiresOpen() public {
        _requestDeposit(alice, 10e6);
        uint256 epoch = _closeAndSettleDeposit(); // epoch 0 now Settled, current is 1
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidEpochState.selector,
                epoch,
                IAsyncFleetGatewayEnums.EpochState.Settled,
                IAsyncFleetGatewayEnums.EpochState.Open
            )
        );
        gateway.retryDepositEpoch(epoch);
    }
}
