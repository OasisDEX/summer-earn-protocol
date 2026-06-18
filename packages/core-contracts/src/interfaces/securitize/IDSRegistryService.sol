// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IDSRegistryService
 * @notice Minimal interface for the Securitize DS Protocol registry service.
 * @dev The registry maps wallets to KYC'd investor IDs. A `DSToken` transfer only succeeds if both
 *      the sender and receiver wallets are registered here (plus compliance rules). An integrating
 *      contract (e.g. an Ark) must therefore itself be a registered wallet before it can hold or
 *      move the token; registration is performed off-chain by Securitize (issuer/exchange role).
 */
interface IDSRegistryService {
    /**
     * @notice Whether `_address` is a registered investor wallet.
     * @param _address The wallet to check
     * @return true if the wallet is registered
     */
    function isWallet(address _address) external view returns (bool);

    /**
     * @notice Returns the investor ID that `_address` belongs to (empty string if unregistered).
     * @param _address The wallet to look up
     * @return The investor ID string
     */
    function getInvestor(
        address _address
    ) external view returns (string memory);
}
