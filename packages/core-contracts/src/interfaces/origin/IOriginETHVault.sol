// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IOriginETHVault
/// @notice Interface for the Origin ETH vault, handling minting and queued withdrawals of OETH
interface IOriginETHVault {
    /// @notice A queued withdrawal request awaiting claim
    /// @param withdrawer The address that requested the withdrawal
    /// @param claimed Whether the request has already been claimed
    /// @param timestamp The timestamp of the withdrawal request
    /// @param amount The amount of oTokens to redeem (e.g. OETH)
    /// @param queued The cumulative total of all withdrawal requests including this one; claimable once the
    ///        queue's claimable amount reaches this value
    struct WithdrawalRequest {
        address withdrawer;
        bool claimed;
        uint40 timestamp; // timestamp of the withdrawal request
        // Amount of oTokens to redeem. eg OETH
        uint128 amount;
        // cumulative total of all withdrawal requests including this one.
        // this request can be claimed when this queued amount is less than or equal to the queue's claimable amount.
        uint128 queued;
    }

    /// @notice Returns the details of a withdrawal request
    /// @param requestId The index of the withdrawal request
    /// @return The withdrawal request data
    function withdrawalRequests(
        uint256 requestId
    ) external view returns (WithdrawalRequest memory);
    /// @notice Mints OETH by depositing the underlying asset
    /// @param to The address of the asset deposited to mint OETH
    /// @param amount The amount of the asset to deposit
    /// @param minShares The minimum amount of OETH to mint (slippage protection)
    function mint(address to, uint256 amount, uint256 minShares) external;
    /// @notice Requests a withdrawal, queueing it for later claim
    /// @param amount The amount of OETH to redeem
    /// @return requestId The index of the created withdrawal request
    /// @return queued The cumulative queued amount for this request
    function requestWithdrawal(
        uint256 amount
    ) external returns (uint256 requestId, uint256 queued);
    /// @notice Claims a single previously requested withdrawal
    /// @param _requestId The index of the withdrawal request to claim
    /// @return amount The amount of assets claimed
    function claimWithdrawal(
        uint256 _requestId
    ) external returns (uint256 amount);
    /// @notice Claims multiple previously requested withdrawals
    /// @param _requestIds The indexes of the withdrawal requests to claim
    /// @return amounts The amounts claimed for each request
    /// @return totalAmount The total amount claimed across all requests
    function claimWithdrawals(
        uint256[] calldata _requestIds
    ) external returns (uint256[] memory amounts, uint256 totalAmount);
}
