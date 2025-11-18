// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StargateAdapterSetupTest} from "./StargateAdapter.setup.t.sol";
import {IStargateAdapter} from "../../../src/interfaces/IStargateAdapter.sol";
import {Bps, toBps, fromBps} from "../../../src/helpers/Bps.sol";
import {BpsUtils} from "../../../src/helpers/BpsUtils.sol";

contract StargateAdapterSlippageGovernanceTest is StargateAdapterSetupTest {
    function testSetSlippageTolerance_OnlyGovernor() public {
        Bps slippageBpsA = BpsUtils.fromIntegerBPS(100);
        Bps slippageBpsB = BpsUtils.fromIntegerBPS(123);
        useNetworkA();

        vm.prank(user);
        // onlyGovernor modifier comes from ProtocolAccessManaged and reverts with CallerIsNotGovernor
        vm.expectRevert();
        adapterA.setSlippageTolerance(slippageBpsA);

        vm.prank(governor);
        adapterA.setSlippageTolerance(slippageBpsB);
        assertEq(
            fromBps(adapterA.slippageToleranceBps()),
            fromBps(slippageBpsB)
        );
    }

    function testSetSlippageTolerance_RevertBelowMin() public {
        Bps invalidSlippageBps = BpsUtils.fromIntegerBPS(0);

        useNetworkA();
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStargateAdapter.InvalidSlippageTolerance.selector,
                fromBps(invalidSlippageBps)
            )
        );
        adapterA.setSlippageTolerance(invalidSlippageBps); // below MIN_SLIPPAGE_BPS (1)
    }

    function testSetSlippageTolerance_RevertAboveMax() public {
        Bps invalidSlippageBps = BpsUtils.fromIntegerBPS(1001);

        useNetworkA();
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStargateAdapter.InvalidSlippageTolerance.selector,
                fromBps(invalidSlippageBps)
            )
        );
        adapterA.setSlippageTolerance(invalidSlippageBps);
    }
}
