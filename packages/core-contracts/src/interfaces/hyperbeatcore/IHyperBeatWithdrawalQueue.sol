// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IHyperBeatPricer.sol";

/**
 * @notice Withdrawal request struct
 */
struct WithdrawalRequest {
    uint256 nonce;
    address initiator;
    address user;
    uint256 amount;
    uint256 createdAt;
    uint128 exchangeRate;
    uint256 baseAssetAmount;
    uint256 minAssetOut;
    uint64 deadline;
}

/**
 * @title IHyperBeatWithdrawalQueue
 * @notice Interface for HyperBeat WithdrawalQueue contract
 */
interface IHyperBeatWithdrawalQueue {
    /**
     * @notice Creates a withdrawal request
     * @param _user The address of the user
     * @param _amount The amount of tokens to withdraw
     * @param _minAssetOut The minimum amount of assets to receive
     * @param _deadline The deadline for the withdrawal request
     * @return The withdrawal request
     */
    function createWithdrawalRequest(
        address _user,
        uint256 _amount,
        uint256 _minAssetOut,
        uint64 _deadline
    ) external returns (WithdrawalRequest memory);

    /**
     * @notice Instantly withdraws tokens
     * @param _user The address of the user
     * @param _amount The amount of tokens to withdraw
     */
    function instantWithdraw(address _user, uint256 _amount) external;

    /**
     * @notice Gets the instant withdrawal fee
     * @return The instant withdrawal fee (in basis points, e.g., 30 = 0.3%)
     */
    function instantWithdrawalFee() external view returns (uint64);

    /**
     * @notice Gets the vault token address
     * @return The address of the vault token
     */
    function vaultToken() external view returns (address);

    /**
     * @notice Gets the pricer address
     * @return The address of the pricer
     */
    function pricer() external view returns (address);

    /**
     * @notice Gets the base asset address
     * @return The address of the base asset
     */
    function baseAsset() external view returns (address);
}
