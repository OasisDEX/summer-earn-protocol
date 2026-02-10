// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IBaseRoundsVault.sol";

/**
    @title IRoundsInputVaultEvents

    @notice The IRoundsInputVaultEvents contract defines the events emitted by the IRoundsInputVault contract.
            These events allow users to track the deposits made in the input vault

    @author Roberto Cano <robercano>
 */
interface IRoundsInputVaultEvents {
    /// Emitted when a user deposits assets into the input vault, indicating the round, the account, the amount of assets and the amount of shares minted
    event AssetsDeposited(
        uint256 indexed roundId,
        address indexed account,
        uint256 assets,
        uint256 shares
    );
}
