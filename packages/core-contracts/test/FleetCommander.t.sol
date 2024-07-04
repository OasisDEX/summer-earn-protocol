// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../src/contracts/FleetCommander.sol";

contract FleetCommanderTest is Test {
    FleetCommander public fleetCommander;
    address public governor = address(1);
    address public raft = address(2);
    address public aaveV3Pool = address(3);
    address public testToken = address(4);

    function setUp() public {
        FleetCommanderParams memory params = FleetCommanderParams({
            governor: governor,
            initialArks : [],
            initialFundsQueueBalance : 0,
            initialRebalanceCooldown:
            raft: raft,
            aaveV3Pool: aaveV3Pool
        });
        fleetCommander = new FleetCommander(params);
    }

    function testDeposit() public {
        vm.prank(governor); // Set msg.sender to governor
//        address newArk = arkFactory.createAaveV3Ark(testToken);
//
//        assertTrue(newArk != address(0));
//        AaveV3Ark ark = AaveV3Ark(newArk);
//        address _token = address(ark.token());
//        AccessControl accessControl = AccessControl(address(ark));
//
//        assertEq(_token, testToken);
//        assertTrue(accessControl.hasRole(ark.GOVERNOR_ROLE(), governor));
//        assertEq(ark.raft(), raft);
    }
}
