// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ISteth
/// @notice Minimal interface for Lido's stETH token
interface ISteth {
    /**
     * @notice Send funds to the pool with optional _referral parameter
     * @dev This function is alternative way to submit funds. Supports optional referral address.
     * @param _referral Optional referral address for tracking
     * @return Amount of StETH shares generated
     */
    function submit(address _referral) external payable returns (uint256);
    /// @notice Returns the stETH balance of an account
    /// @param _account The account to query
    /// @return The stETH balance
    function balanceOf(address _account) external view returns (uint256);
    /// @notice Returns the amount of shares owned by an account
    /// @param _account The account to query
    /// @return The share amount
    function sharesOf(address _account) external view returns (uint256);
    /// @notice Approves a spender to transfer the caller's stETH
    /// @param _spender The address allowed to spend
    /// @param _amount The amount approved
    /// @return True if the approval succeeded
    function approve(address _spender, uint256 _amount) external returns (bool);
    /// @notice Converts an amount of shares to the equivalent amount of pooled ETH (stETH)
    /// @param _shares The amount of shares
    /// @return The equivalent amount of pooled ETH
    function getPooledEthByShares(
        uint256 _shares
    ) external view returns (uint256);
    /// @notice Converts an amount of pooled ETH (stETH) to the equivalent amount of shares
    /// @param _ethAmount The amount of pooled ETH
    /// @return The equivalent amount of shares
    function getSharesByPooledEth(
        uint256 _ethAmount
    ) external view returns (uint256);
}
