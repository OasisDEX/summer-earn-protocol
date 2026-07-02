// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IEscrow
 * @notice Interface for Escrow contracts that hold yield/tokens for specific solvers and intents.
 */
interface IEscrow {
    /**
     * @notice Deposits a specified amount of an asset into the escrow for a specific intent ID.
     * @param asset The address of the asset/token to deposit.
     * @param amount The amount of the asset to deposit.
     * @param intentId The unique identifier of the intent associated with the deposit.
     */
    function deposit(address asset, uint256 amount, bytes32 intentId) external;

    /**
     * @notice Withdraws the escrowed asset for a specific intent ID to a destination address.
     * @param asset The address of the asset/token to withdraw.
     * @param to The address to receive the withdrawn asset.
     * @param intentId The unique identifier of the intent associated with the withdrawal.
     * @return amount The amount of the asset withdrawn.
     */
    function withdraw(
        address asset,
        address to,
        bytes32 intentId
    ) external returns (uint256 amount);
}
