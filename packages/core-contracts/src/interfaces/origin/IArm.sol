// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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

    function swapExactTokensForTokens(
        address inToken,
        address outToken,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external;

    function balanceOf(address account) external view returns (uint256);

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

    function withdrawalRequests(
        uint256 requestId
    ) external view returns (WithdrawalRequest memory);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function previewRedeem(uint256 shares) external view returns (uint256);

    function deposit(uint256 assets, address receiver) external;
}
