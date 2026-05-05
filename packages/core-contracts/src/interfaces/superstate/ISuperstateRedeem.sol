// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title Superstate Redeem Interface
 * @notice Interface for the Superstate redemption mechanism.
 */
interface ISuperstateRedeem {
    /**
     * @notice Redeems Superstate Fund Tokens for USDC.
     * @dev The caller MUST be on the Superstate on-chain Allowlist, and the `to` address must be allowlisted.
     * @param amount The amount of fund tokens to redeem.
     * @param to The address to receive the USDC payout.
     */
    function redeem(uint256 amount, address to) external;
}
