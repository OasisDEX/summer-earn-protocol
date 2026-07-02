// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @notice Configuration for a stablecoin accepted for subscriptions
/// @param sweepDestination The address that received subscribed stablecoins are swept to
/// @param fee The subscription fee charged for this stablecoin
struct SupportedStablecoin {
    address sweepDestination;
    uint96 fee;
}

/**
 * @title Superstate Token Interface
 * @notice Combined interface for Superstate fund tokens (e.g. USTB, USCC), covering subscriptions,
 *         stablecoin configuration, and oracle access.
 */
interface ISuperstateToken {
    /**
     * @notice Subscribes to mint Superstate Fund Tokens to a designated address.
     * @dev The caller MUST be on the Superstate on-chain Allowlist, and the `to` address must be allowlisted.
     * @param to The address to receive the minted fund tokens.
     * @param inAmount The amount of stablecoin to subscribe.
     * @param stablecoin The address of the stablecoin to use.
     */
    function subscribe(
        address to,
        uint256 inAmount,
        address stablecoin
    ) external;

    /**
     * @notice Subscribes to mint Superstate Fund Tokens to the caller.
     * @dev The caller MUST be on the Superstate on-chain Allowlist.
     * @param inAmount The amount of stablecoin to subscribe.
     * @param stablecoin The address of the stablecoin to use.
     */
    function subscribe(uint256 inAmount, address stablecoin) external;

    /**
     * @notice Returns the supported stablecoin configuration for a given stablecoin address.
     * @param stablecoin The stablecoin address to query.
     * @return The SupportedStablecoin struct containing the sweep destination and fee.
     */
    function supportedStablecoins(
        address stablecoin
    ) external view returns (SupportedStablecoin memory);

    /**
     * @notice Initiates an off-chain redemption of Superstate Fund Tokens.
     * @dev Burns the caller's fund tokens and triggers off-chain USDC settlement (T+1/T+2).
     * @param amount The amount of fund tokens to redeem.
     */
    function offchainRedeem(uint256 amount) external;

    /**
     * @notice Returns the oracle configured for this Superstate token.
     * @dev Used during deployment of SuperstateSubscribeArk to validate that the passed
     *      oracle address matches the one the token contract itself is configured with.
     * @return The address of the configured oracle.
     */
    function superstateOracle() external returns (address);
}
