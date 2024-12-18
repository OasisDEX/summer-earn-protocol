// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {StdStorage, Test, console, stdStorage} from "forge-std/Test.sol";

/**
 * @title FleetCommanderStorageWriter
 * @notice Helper contract to write to FleetCommander internal storage variables
 */
contract FleetCommanderStorageWriter is Test {
    using stdStorage for StdStorage;

    address public fleetCommander;

    uint256 public configSlot;
    uint256 public tipRateSlot;

    constructor(address fleetCommander_) {
        fleetCommander = fleetCommander_;

        configSlot = stdstore
            .target(fleetCommander)
            .sig(FleetCommander(fleetCommander).config.selector)
            .find();

        tipRateSlot = stdstore
            .target(fleetCommander)
            .sig(FleetCommander(fleetCommander).tipRate.selector)
            .find();
    }

    function setminimumBufferBalance(uint256 value) public {
        bytes32 slot = bytes32(configSlot);
        bytes32 minimumBufferBalanceSlot = bytes32(uint256(slot) + 1); // Offset for minimumBufferBalance in the struct
        vm.store(fleetCommander, minimumBufferBalanceSlot, bytes32(value));
    }

    function setDepositCap(uint256 value) public {
        bytes32 slot = bytes32(configSlot);
        bytes32 depositCapSlot = bytes32(uint256(slot) + 2); // Offset for depositCap in the struct
        vm.store(fleetCommander, depositCapSlot, bytes32(value));
    }

    function setTipRate(uint256 value) public {
        bytes32 slot = bytes32(tipRateSlot);
        vm.store(fleetCommander, slot, bytes32(value));
    }

    function test() public {}
}
