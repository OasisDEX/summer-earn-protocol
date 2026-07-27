// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IArm
/// @notice Interface for the Origin Automated Redemption Manager (ARM)
interface IArm {
    /// @notice Request to redeem liquidity provider shares for liquidity assets
    /// @param shares The amount of shares the redeemer wants to burn for liquidity assets
    /// @return requestId The index of the withdrawal request
    /// @return assets The amount of liquidity assets that will be claimable by the redeemer
    function requestRedeem(
        uint256 shares
    ) external returns (uint256 requestId, uint256 assets);

    /// @notice Claim a redemption request
    /// @param requestId The index of the withdrawal request
    /// @return assets The amount of liquidity assets that will be claimable by the redeemer
    function claimRedeem(uint256 requestId) external returns (uint256 assets);

    /// @notice Swap tokens for tokens
    /// @param inToken The token to swap from
    /// @param outToken The token to swap to
    /// @param amountIn The amount of input tokens to swap
    /// @param amountOutMin The minimum amount of output tokens to receive
    /// @param to The recipient of the output tokens
    function swapExactTokensForTokens(
        address inToken,
        address outToken,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external;

    /// @notice Returns the liquidity provider share balance of an account
    /// @param account The account to query
    /// @return The share balance
    function balanceOf(address account) external view returns (uint256);

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

    /// @notice Converts an amount of shares to the equivalent amount of assets
    /// @param shares The amount of shares
    /// @return The equivalent amount of assets
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Converts an amount of assets to the equivalent amount of shares
    /// @param assets The amount of assets
    /// @return The equivalent amount of shares
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Previews the amount of assets received for redeeming shares
    /// @param shares The amount of shares to redeem
    /// @return The amount of assets that would be received
    function previewRedeem(uint256 shares) external view returns (uint256);

    /// @notice Deposits assets into the ARM, minting shares to the receiver
    /// @param assets The amount of assets to deposit
    /// @param receiver The address that receives the minted shares
    function deposit(uint256 assets, address receiver) external;
}
