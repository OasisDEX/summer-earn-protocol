// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IUpshiftVault
 * @notice Interface for the Upshift ERC4626 vault with epoch-based asynchronous withdrawals
 */
interface IUpshiftVault is IERC4626 {
    /// @notice Requests an asynchronous redemption of shares, scheduling a claim in a future epoch
    /// @param shares The amount of shares to redeem
    /// @param receiverAddr The address that will receive the assets on claim
    /// @param holderAddr The address whose shares are redeemed
    /// @return assets The amount of assets that will be claimable
    /// @return claimableEpoch The epoch at which the assets become claimable
    function requestRedeem(
        uint256 shares,
        address receiverAddr,
        address holderAddr
    ) external returns (uint256 assets, uint256 claimableEpoch);

    /// @notice Claims assets from a previously requested redemption scheduled for the given date
    /// @param year The year component of the scheduled withdrawal date
    /// @param month The month component of the scheduled withdrawal date
    /// @param day The day component of the scheduled withdrawal date
    /// @param receiverAddr The address receiving the claimed assets
    /// @return The amount of assets claimed
    /// @return The remaining or processed amount associated with the claim
    function claim(
        uint256 year,
        uint256 month,
        uint256 day,
        address receiverAddr
    ) external returns (uint256, uint256);

    /// @notice Returns the current withdrawal epoch date and its claimable epoch
    /// @return year The year component of the current withdrawal date
    /// @return month The month component of the current withdrawal date
    /// @return day The day component of the current withdrawal date
    /// @return claimableEpoch The epoch at which withdrawals for this date become claimable
    function getWithdrawalEpoch()
        external
        view
        returns (
            uint256 year,
            uint256 month,
            uint256 day,
            uint256 claimableEpoch
        );

    /// @notice Returns the amount claimable by a receiver for a scheduled withdrawal date
    /// @param year The year component of the withdrawal date
    /// @param month The month component of the withdrawal date
    /// @param day The day component of the withdrawal date
    /// @param receiverAddr The receiver whose claimable amount is queried
    /// @return The claimable asset amount
    function getClaimableAmountByReceiver(
        uint256 year,
        uint256 month,
        uint256 day,
        address receiverAddr
    ) external view returns (uint256);

    /// @notice Returns the scheduled transactions for a withdrawal date and their execution epoch
    /// @param year The year component of the withdrawal date
    /// @param month The month component of the withdrawal date
    /// @param day The day component of the withdrawal date
    /// @return totalTransactions The number of transactions scheduled for the date
    /// @return executionEpoch The epoch at which the scheduled transactions execute
    function getScheduledTransactionsByDate(
        uint256 year,
        uint256 month,
        uint256 day
    ) external view returns (uint256 totalTransactions, uint256 executionEpoch);

    /// @notice Processes outstanding claims for a withdrawal date, up to a limit
    /// @param year The year component of the withdrawal date
    /// @param month The month component of the withdrawal date
    /// @param day The day component of the withdrawal date
    /// @param limit The maximum number of claims to process
    function processAllClaimsByDate(
        uint256 year,
        uint256 month,
        uint256 day,
        uint256 limit
    ) external;

    /// @notice Returns the lag duration between a redeem request and when it becomes claimable
    /// @return The lag duration in seconds
    function lagDuration() external view returns (uint256);
}
