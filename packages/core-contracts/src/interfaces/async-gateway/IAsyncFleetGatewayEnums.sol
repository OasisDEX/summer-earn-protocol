// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IAsyncFleetGatewayEnums {
    /// @notice Lifecycle of one epoch (per flow). NotOpened is the mapping default.
    enum EpochState {
        NotOpened,
        Open,
        InSettlement,
        Settled
    }
}
