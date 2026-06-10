// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRwaOracleErrors
 * @notice Interface defining errors raised by the Real World Asset (RWA) Oracle contract.
 */
interface IRwaOracleErrors {
    /**
     * @notice Reverted when a signature verification fails.
     */
    error InvalidSignature();

    /**
     * @notice Reverted when the number of valid signatures is below the threshold.
     */
    error NotEnoughSignatures();

    /**
     * @notice Reverted when a price update payload has a timestamp that is too old.
     */
    error StalePrice();

    /**
     * @notice Reverted when a price update payload has a timestamp from the future.
     */
    error FuturePrice();

    /**
     * @notice Reverted when a caller lacks the required permissions for an administrative action.
     */
    error Unauthorized();

    /**
     * @notice Reverted when configuring invalid state variables (e.g. threshold > total signers).
     */
    error InvalidConfiguration();

    /**
     * @notice Reverted when adding a signer that is already registered.
     */
    error DuplicateSigner();

    /**
     * @notice Reverted when querying price data but no prices have been set yet.
     */
    error NoDataPresent();
}

