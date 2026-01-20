// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IHyperBeatCoreArkErrors
 * @notice Custom errors for the HyperBeatCoreArk contract
 * @dev Errors are prefixed with HyperBeatCoreArk__ to distinguish from base Ark errors
 */
interface IHyperBeatCoreArkErrors {
    /// @notice Thrown when the depositor address is invalid (zero address)
    error HyperBeatCoreArk__InvalidDepositor();

    /// @notice Thrown when the withdrawal queue address is invalid (zero address)
    error HyperBeatCoreArk__InvalidWithdrawalQueue();

    /// @notice Thrown when the pricer address is invalid (zero address)
    error HyperBeatCoreArk__InvalidPricer();

    /// @notice Thrown when the vault token address is invalid (zero address)
    error HyperBeatCoreArk__InvalidVaultTokenAddress();

    /// @notice Thrown when the vault token decimals are invalid (less than asset decimals)
    error HyperBeatCoreArk__InvalidVaultTokenDecimals();
}
