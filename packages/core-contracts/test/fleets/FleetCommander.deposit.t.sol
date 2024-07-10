// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderHelpers.sol";

/**
 * @title Deposit test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's deposit functionality
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Deposit
 * - Error cases and edge scenarios
 */
contract Deposit is Test, ArkTestHelpers, FleetCommanderTestBase {
    function setUp() public {
        fleetCommander = new FleetCommander(defaultFleetCommanderParams);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );

        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        mockArk1.grantCommanderRole(address(fleetCommander));
        mockArk2.grantCommanderRole(address(fleetCommander));
        mockArk3.grantCommanderRole(address(fleetCommander));
        vm.stopPrank();
    }

    function test_Deposit() public {
        uint256 amount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);
        mockToken.mint(mockUser, amount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), amount);
        mockArkTotalAssets(ark1, 0);
        mockArkTotalAssets(ark2, 0);

        vm.prank(mockUser);
        fleetCommander.deposit(amount, mockUser);

        assertEq(amount, fleetCommander.balanceOf(mockUser));
    }
}
