// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IRoundsVaultBase.sol";

/**
    @title IRoundsVaultInputEvents

    @notice Events specific to the Input flavor of `RoundsVaultBase`.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultInputEvents {
    /// @notice Emitted by `RoundsVaultInput._operate` when the keeper settles a round and the frozen
    ///         underlying-asset liability is deposited into the target vault.
    /// @param roundId The id of the round being settled
    /// @param account The address that triggered the settlement (the keeper for normal flows)
    /// @param assets The amount of underlying asset that was deposited into the target vault
    /// @param shares The amount of target-vault shares received in return
    event AssetsDeposited(
        uint256 indexed roundId,
        address indexed account,
        uint256 assets,
        uint256 shares
    );
}
