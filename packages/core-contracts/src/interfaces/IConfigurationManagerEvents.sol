// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IConfigurationManagerEvents {
    event GovernorUpdated(address newGovernor);
    event RaftUpdated(address newRaft);
}
