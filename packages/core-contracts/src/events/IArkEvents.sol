// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IArkEvents {
    event Harvested(uint256 amount);
    event Boarded(address indexed commander, address token, uint256 amount);
    event Disembarked(address indexed commander, address token, uint256 amount);
    event DepositCapUpdated(uint256 newCap);
    event RaftUpdated(address newRaft);
}
