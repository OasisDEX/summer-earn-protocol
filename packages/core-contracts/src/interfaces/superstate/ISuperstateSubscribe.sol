// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title Superstate Subscribe Interface
 * @notice Interface for the Superstate subscription mechanism.
 */
interface ISuperstateSubscribe {
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
}
