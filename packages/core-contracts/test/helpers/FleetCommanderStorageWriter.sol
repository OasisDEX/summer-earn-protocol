// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console, stdStorage, StdStorage} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";

/**
 * @title FleetCommanderStorageWriter
 * @notice Helper contract to write to FleetCommander internal storage variables
 */
contract FleetCommanderStorageWriter is Test {
    using stdStorage for StdStorage;

    address public fleetCommander;

    uint256 public FundsBufferBalanceSlot;
    uint256 public MinFundsBufferBalanceSlot;

    constructor(address fleetCommander_) {
        fleetCommander = fleetCommander_;

        FundsBufferBalanceSlot = stdstore
            .target(fleetCommander)
            .sig(FleetCommander(fleetCommander).fundsBufferBalance.selector)
            .find();

        MinFundsBufferBalanceSlot = stdstore
            .target(fleetCommander)
            .sig(FleetCommander(fleetCommander).minFundsBufferBalance.selector)
            .find();
    }

    function setFundsBufferBalance(uint256 value) public {
        vm.store(
            fleetCommander,
            bytes32(FundsBufferBalanceSlot),
            bytes32(value)
        );
    }

    function setMinFundsBufferBalance(uint256 value) public {
        vm.store(
            fleetCommander,
            bytes32(MinFundsBufferBalanceSlot),
            bytes32(value)
        );
    }
}
