// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IMidasArkErrors
 * @notice Custom errors for the MidasArk contract
 * @dev Errors are prefixed with MidasArk__ to distinguish from base Ark errors
 */
interface IMidasArkErrors {
    /// @notice Thrown when the issuance vault address is invalid (zero address)
    error MidasArk__InvalidIssuanceVault();

    /// @notice Thrown when the redemption vault address is invalid (zero address)
    error MidasArk__InvalidRedemptionVault();

    /// @notice Thrown when the oracle address is invalid (zero address)
    error MidasArk__InvalidOracle();

    /// @notice Thrown when the withdrawal manager address is invalid (zero address)
    error MidasArk__InvalidWithdrawalManager();

    /// @notice Thrown when the mToken address is invalid (zero address)
    error MidasArk__InvalidMTokenAddress();

    /// @notice Thrown when the data feed is invalid
    error MidasArk__InvalidDataFeed();

    /// @notice Thrown when the mToken decimals are invalid (less than asset decimals)
    error MidasArk__InvalidMTokenDecimals();
}
