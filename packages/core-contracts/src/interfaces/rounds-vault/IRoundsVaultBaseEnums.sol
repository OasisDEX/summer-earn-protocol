// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IRoundsVaultBaseEnums {
    /// @notice Flavor of a `RoundsVaultBase` instance. Determines the deposit and exchange assets.
    enum BaseVaultType {
        Input, /// @notice Deposit asset is the target vault's underlying; exchange asset is the target vault's shares.
        Output /// @notice Deposit asset is the target vault's shares; exchange asset is the target vault's underlying.
    }

    /// @notice Progression of states for an individual round.
    /// @dev `NotOpened` is the EVM default for any id never written to; the constructor writes
    ///      `Opened` to round 0 so the first round is usable at deployment time.
    enum RoundState {
        NotOpened, /// @notice The round has not been opened yet. Default zero value for unused round ids.
        Opened, /// @notice The round is open: it accepts deposits and current-round receipt redemptions.
        InSettlement, /// @notice The round is closed; its supply is frozen and awaiting settlement.
        Settled /// @notice The settlement trade has executed; receipts for this round are now exchangeable for the exchange asset at the snapshotted rate.
    }
}
