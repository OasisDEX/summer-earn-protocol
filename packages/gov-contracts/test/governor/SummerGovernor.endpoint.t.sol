// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SummerGovernorTestBase} from "./SummerGovernorTestBase.sol";

contract SummerGovernorEndpointTest is SummerGovernorTestBase {
    address public delegate = address(0xbeef);

    function test_SetDelegate() public {
        address nonOwner = address(0xdead);

        // Only owner can set delegate
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                nonOwner
            )
        );
        governorA.setDelegate(delegate);

        // Timelock (new owner) can set delegate
        vm.prank(address(timelockA));
        governorA.setDelegate(delegate);

        // Can set delegate to zero address
        vm.prank(address(timelockA));
        governorA.setDelegate(address(0));
    }
}
