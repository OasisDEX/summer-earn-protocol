// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IConfigurationManagerEvents {
    event RaftUpdated(address newRaft);
    event TipRateUpdated(uint8 newTipRate);
}
