// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IRoundsVaultBaseEnums {
    enum BaseVaultType {
        Input, /// @notice The vault accepts underlying assets and deposits them into the target vault.
        Output /// @notice The vault accepts target vault shares and redeems them for underlying assets.
    }

    /// @notice Defines the progression of states for an individual round in the vault.
    enum RoundState {
        NotOpened, /// @notice The round has not started yet. Default state.
        Opened, /// @notice The round is the active, current round accepting deposits.
        InSettlement, /// @notice The round has ended and funds are being settled.
        Settled /// @notice Settlement is finished and assets are ready for redemption.
    }
}
