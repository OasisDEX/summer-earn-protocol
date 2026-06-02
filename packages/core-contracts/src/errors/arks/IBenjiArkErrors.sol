// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IBenjiArkErrors
 * @notice Custom errors for `BenjiArk`
 */
interface IBenjiArkErrors {
    /// @notice Reverts when `whitelistSwapPool` is given the zero address.
    error InvalidSwapPoolAddress();

    /// @notice Reverts when the constructor is given a zero iBENJI share-token address.
    error InvalidShareTokenAddress();

    /// @notice Reverts when the constructor is given `ArkParams` with `requiresKeeperData` unset.
    ///         The keeper must supply the SwapPool address via `boardData`/`disembarkData`, so the
    ///         flag is mandatory for this Ark.
    error MustRequireKeeperData();

    /// @notice Reverts when `boardData`/`disembarkData` is not exactly one ABI-encoded address.
    error InvalidSwapPoolData();

    /// @notice Reverts when the keeper-supplied SwapPool is not on the curator whitelist.
    /// @param swapPool The SwapPool address supplied via `boardData`/`disembarkData`
    error SwapPoolNotWhitelisted(address swapPool);

    /// @notice Reverts in `_board` when this Ark is not an authorized SwapPool trader for the
    ///         asset/iBENJI pair (so the swap would revert and strand the asset).
    error ArkNotAuthorized();

    /// @notice Reverts in `whitelistSwapPool` when the configured asset/iBENJI pair is not
    ///         authorized on the pool being whitelisted (so the Ark could never board or disembark
    ///         through it). Pair authorization is a pool-wide setting independent of this Ark's
    ///         per-trader authorization.
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
