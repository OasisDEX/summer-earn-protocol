// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface IDCAStrategyManagerErrors {
    /// @notice Reverts when the `StrategyConfig` supplied by the caller does not hash
    ///         to the commitment stored for `strategyId`. Either the wrong config was
    ///         passed or the strategy has been edited since the caller last fetched it.
    error CommitmentMismatch(uint256 strategyId);

    /// @notice Reverts when `createStrategy` or `editStrategy` would register a
    ///         commitment hash that is already active. Identical strategies are
    ///         rejected; mutate at least one field to create a distinct strategy.
    error DuplicateStrategy();

    /// @notice Reverts when an operation requires a specific status that the strategy
    ///         does not currently have (e.g. pausing a non-ACTIVE strategy, resuming a
    ///         non-PAUSED strategy, or executing a CANCELLED/COMPLETED one).
    error StrategyNotActive(uint256 strategyId);

    /// @notice Reverts when `executeStrategy` is called before `nextTriggerAt`.
    ///         `nextTriggerAt` is the earliest Unix timestamp the keeper may execute.
    error ExecutionWindowNotReached(
        uint256 strategyId,
        uint256 nextTriggerAt,
        uint256 blockTimestamp
    );

    /// @notice Reverts when the amount of target-vault shares received from the Enso
    ///         swap is less than the slippage-adjusted minimum (`minOut`).
    error SwapOutputBelowMinOut(
        uint256 strategyId,
        uint256 minOut,
        uint256 actualOut
    );

    /// @notice Reverts when `targetVault.convertToShares(expectedOutAssets)` returns
    ///         zero. With zero expected output, `minOut = 0` and the slippage floor
    ///         is silently disabled — this guard refuses to execute such trades.
    error ZeroExpectedOutShares();

    /// @notice Reverts when `sourceVault.deposit` during a deposit-and-create mints
    ///         fewer shares than the caller's `expectedMinShares` floor.
    error DepositSharesBelowMin(uint256 expected, uint256 received);

    /// @notice Reverts when the caller is not `config.owner` on an owner-gated function,
    ///         or when `editStrategy` attempts to change `config.owner` (ownership
    ///         transfer via edit is disallowed; cancel and recreate instead).
    error UnauthorizedAccess(uint256 strategyId, address caller);

    /// @notice Reverts when the caller is not creating the strategy for themselves.
    error UnauthorizedOwner(address caller, address owner);

    /// @notice Reverts when `config.slippageBps` exceeds the protocol cap (50%, i.e. 5_000 BPS).
    error InvalidSlippage(uint256 slippageBps);

    /// @notice Reverts when `config.tradeAmount` is zero.
    error ZeroTradeAmount();

    /// @notice Reverts when `config.maxTrades` is zero. Zero is NOT a sentinel for
    ///         "unlimited"; a positive trade cap is required.
    error ZeroMaxTrades();

    /// @notice Reverts when `config.owner` is the zero address.
    error InvalidOwner();

    /// @notice Reverts when `config.sourceVault == config.targetVault` or
    ///         `config.inAsset == config.outAsset`.
    error SameAsset(address asset);

    /// @notice Reverts when `config.inAsset` does not match `config.sourceVault.asset()`.
    ///         The slippage floor relies on the oracle pricing the correct underlying.
    error InAssetVaultMismatch(address expected, address actual);

    /// @notice Reverts when `config.outAsset` does not match `config.targetVault.asset()`.
    ///         The slippage floor relies on the oracle pricing the correct underlying.
    error OutAssetVaultMismatch(address expected, address actual);

    /// @notice Reverts when `config.interval` is below the contract minimum (1 day).
    error IntervalTooShort(uint256 provided, uint256 minimum);

    /// @notice Reverts when `config.interval` is above the contract maximum (90 days).
    error IntervalTooLong(uint256 provided, uint256 maximum);

    /// @notice Reverts when `depositAndCreate` is called with `assetAmount == 0`.
    error ZeroDeposit();

    /// @notice Reverts when `config.inAssetFeed` or `config.outAssetFeed` is the zero address.
    error InvalidFeedAddress();

    /// @notice Reverts when the current oracle execution price exceeds `config.maxPrice`.
    ///         `executionPrice` is the 1e18-scaled price of `outAsset` denominated
    ///         in `inAsset` (inAsset units per outAsset unit).
    error PriceAboveCeiling(uint256 executionPrice, uint256 maxPrice);

    /// @notice Reverts when the current oracle execution price is below `config.minPrice`.
    ///         `executionPrice` is the 1e18-scaled price of `outAsset` denominated
    ///         in `inAsset` (inAsset units per outAsset unit).
    error PriceBelowFloor(uint256 executionPrice, uint256 minPrice);

    /// @notice Reverts when both `config.maxPrice` and `config.minPrice` are non-zero
    ///         and `minPrice > maxPrice`. Such a configuration is unsatisfiable and
    ///         would leave the strategy permanently un-executable.
    error InvalidPriceBounds(uint256 minPrice, uint256 maxPrice);

    /// @notice Reverts when the Permit2 sub-allowance signed by the owner does not
    ///         cover the worst-case total spend (`tradeAmount * maxTrades`).
    error Permit2AllowanceInsufficient(uint160 signed, uint256 required);

    /// @notice Reverts when the Permit2 sub-allowance expiration is earlier than
    ///         the strategy's `endDate`. Only enforced when `endDate > 0`.
    error Permit2ExpirationTooEarly(uint48 expiration, uint256 endDate);

    /// @notice Reverts when `config.tradeAmount` exceeds `type(uint160).max`, the
    ///         cap imposed by Permit2 AllowanceTransfer. Such a strategy would be
    ///         created but never executable (the keeper's pull would revert).
    error TradeAmountTooLarge(uint256 tradeAmount);
}
