// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRwaOracleErrors
 * @notice Interface defining errors raised by the Real World Asset (RWA) Oracle contract.
 */
interface IRwaOracleErrors {
    /**
     * @notice Reverted when submitted signatures are not strictly ascending by
     *         signer address (i.e. unsorted or containing a duplicate signer).
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
     * @notice Reverted when a recovered signer is not an authorized signer.
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
     * @notice Reverted when querying price data before any price has been set,
     *         or when the queried round ID is zero or out of range.
     */
    error NoDataPresent();
}
