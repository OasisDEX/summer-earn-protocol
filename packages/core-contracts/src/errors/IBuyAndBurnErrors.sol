// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IBuyAndBurnErrors
 * @dev This file contains custom error definitions for the BuyAndBurn contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IBuyAndBurnErrors {
    /**
     * @notice Thrown when attempting to start a new auction for a token that already has an ongoing auction.
     * @param tokenToAuction The address of the token for which an auction is already running.
     */
    error BuyAndBurnAuctionAlreadyRunning(address tokenToAuction);

    /**
     * @notice Error thrown when trying to start an auction without setting parameters
     * @param token The address of the token for which the auction is being started
     */
    error BuyAndBurnAuctionParametersNotSet(address token);

    /**
     * @notice Error thrown when trying to set invalid auction parameters
     * @param token The address of the token for which the auction is being started
     */
    error BuyAndBurnInvalidAuctionParameters(address token);
}
