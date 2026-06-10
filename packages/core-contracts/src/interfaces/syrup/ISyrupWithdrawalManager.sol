// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ISyrupWithdrawalManager
/// @notice Interface for the legacy Maple Syrup withdrawal manager
interface ISyrupWithdrawalManager {
    /// @notice A pending withdrawal request
    /// @param owner The address that owns the request
    /// @param shares The amount of shares pending redemption
    struct WithdrawalRequest {
        address owner;
        uint256 shares;
    }

    /// @notice Returns the active withdrawal request id for an owner
    /// @param owner_ The account to query
    /// @return The request id
    function requestIds(address owner_) external view returns (uint128);

    /// @notice Returns the withdrawal request data for a request id
    /// @param requestId_ The withdrawal request id
    /// @return The withdrawal request data
    function requests(
        uint128 requestId_
    ) external view returns (WithdrawalRequest memory);
}
