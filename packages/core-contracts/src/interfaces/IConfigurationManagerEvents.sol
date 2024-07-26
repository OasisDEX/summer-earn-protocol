// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IConfigurationManagerEvents {
    event RaftUpdated(address newRaft);
    event TipJarUpdated(address newTipJar);
    event TipRateUpdated(uint8 newTipRate);
}
