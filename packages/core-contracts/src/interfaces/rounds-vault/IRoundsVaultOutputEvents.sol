// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IRoundsVaultBase.sol";

/**
    @title IRoundsVaultOutputEvents

    @notice Events specific to the Output flavor of `RoundsVaultBase`.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultOutputEvents {
    /// @notice Emitted by `RoundsVaultOutput._operate` when the keeper settles a round and the frozen
    ///         target-vault shares are redeemed from the target vault for its underlying asset.
    /// @param roundId The id of the round being settled
    /// @param account The address that triggered the settlement (the keeper for normal flows)
    /// @param shares The amount of target-vault shares that were redeemed
    /// @param assets The amount of underlying asset received from the target vault
    event SharesRedeemed(
        uint256 indexed roundId,
        address indexed account,
        uint256 shares,
        uint256 assets
    );
}
