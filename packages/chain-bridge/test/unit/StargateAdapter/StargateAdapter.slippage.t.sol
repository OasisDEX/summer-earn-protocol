// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {BaseBridgeAdapter} from "../../../src/base/BaseBridgeAdapter.sol";
import {IBaseBridgeAdapterErrors} from "../../../src/interfaces/IBaseBridgeAdapterErrors.sol";
import {StargateAdapter} from "../../../src/adapters/StargateAdapter.sol";
import {Bps, toBps, fromBps} from "../../../src/helpers/Bps.sol";

contract StargateAdapterSlippageGovernanceTest is StargateAdapterSetupTest {
    function testSetSlippageTolerance_OnlyGovernor() public {
        useNetworkA();

        vm.prank(user);
        // onlyGovernor modifier comes from ProtocolAccessManaged and reverts with CallerIsNotGovernor
        vm.expectRevert();
        adapterA.setSlippageTolerance(toBps(100));

        vm.prank(governor);
        adapterA.setSlippageTolerance(toBps(123));
        assertEq(fromBps(adapterA.slippageToleranceBps()), 123);
    }

    function testSetSlippageTolerance_RevertBelowMin() public {
        useNetworkA();
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                StargateAdapter.InvalidSlippageTolerance.selector,
                0
            )
        );
        adapterA.setSlippageTolerance(toBps(0)); // below MIN_SLIPPAGE_BPS (1)
    }

    function testSetSlippageTolerance_RevertAboveMax() public {
        useNetworkA();
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                StargateAdapter.InvalidSlippageTolerance.selector,
                1001
            )
        );
        adapterA.setSlippageTolerance(toBps(1001)); // above MAX_SLIPPAGE_BPS (1000)
    }
}
