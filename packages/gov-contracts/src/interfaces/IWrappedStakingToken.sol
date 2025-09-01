// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IWrappedStakingToken
 * @notice Minimal interface for the wrapped staking token used by SummerStaking
 */
interface IWrappedStakingToken {
    /**
     * @notice Deposit underlying tokens and mint wrapped tokens to `account`
     * @param account The beneficiary account
     * @param amount The amount of underlying tokens to deposit
     * @return success True if the operation succeeded
     */
    function depositFor(
        address account,
        uint256 amount
    ) external returns (bool success);

    /**
     * @notice Burn wrapped tokens and withdraw underlying tokens to `account`
     * @param account The beneficiary account
     * @param amount The amount of underlying tokens to withdraw
     * @return success True if the operation succeeded
     */
    function withdrawTo(
        address account,
        uint256 amount
    ) external returns (bool success);
}
