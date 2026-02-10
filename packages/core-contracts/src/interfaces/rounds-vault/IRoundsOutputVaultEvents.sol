// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IBaseRoundsVault.sol";

/**
    @title IRoundsOutputVaultEvents

    @notice The IRoundsOutputVaultEvents contract defines the events emitted by the IRoundsOutputVault contract.
            These events allow users to track the redemptions made in the output vault.

    @author Roberto Cano <robercano>
 */
interface IRoundsOutputVaultEvents {
    /// Emitted when a user redeems shares from the output vault, indicating the round, the account, the amount of shares and the amount of assets received
    event SharesRedeemed(
        uint256 indexed roundId,
        address indexed account,
        uint256 shares,
        uint256 assets
    );
}
