// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title IBenjiArkErrors
 * @notice Custom errors for `BenjiArk`
 */
interface IBenjiArkErrors {
    /// @notice Reverts when the constructor is given a zero SwapPool address.
    error InvalidSwapPoolAddress();

    /// @notice Reverts when the constructor is given a zero iBENJI share-token address.
    error InvalidShareTokenAddress();

    /// @notice Reverts when the constructor or `setDepositSlippage` is given a value above
    ///         `MAX_DEPOSIT_SLIPPAGE`.
    /// @param newSlippage The supplied slippage
    /// @param maxSlippage The hard cap (`MAX_DEPOSIT_SLIPPAGE`)
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );

    /// @notice Reverts in `_board` when this Ark is not an authorized SwapPool trader for the
    ///         asset/iBENJI pair (so the swap would revert and strand the asset).
    error ArkNotAuthorized();

    /// @notice Reverts in the constructor when the configured asset/iBENJI pair is not authorized on
    ///         the SwapPool (so the Ark could never board or disembark). Pair authorization is a
    ///         pool-wide setting independent of this Ark's per-trader authorization.
    error PairNotAuthorized();

    /// @notice Reverts in `_board` when the iBENJI received from the SwapPool is below the 1:1
    ///         expectation minus `depositSlippage`.
    /// @param expectedShares 1:1 decimal-normalized shares for the deposited amount
    /// @param receivedShares iBENJI balance delta actually delivered by the SwapPool
    error SharesNotReceived(uint256 expectedShares, uint256 receivedShares);

    /// @notice Reverts in `_disembark` when the base asset received from the SwapPool is below the
    ///         requested amount (the 1:1 redemption underdelivered).
    /// @param requestedAssets The asset amount the keeper asked to free
    /// @param receivedAssets The base-asset balance delta delivered by the SwapPool
    error InsufficientAssetsReceived(
        uint256 requestedAssets,
        uint256 receivedAssets
    );
}
