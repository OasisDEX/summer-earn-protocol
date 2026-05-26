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

    /// @notice Reverts when `executeStrategy` is called on a strategy that has already
    ///         reached a terminal condition before the trade runs: `maxTrades` exhausted
    ///         or `endDate` passed. `reason` is `"max_trades"` or `"end_date"`.
    error TerminalStateReached(uint256 strategyId, bytes32 reason);

    /// @notice Reverts when the caller is not `config.owner` on an owner-gated function,
    ///         or when `editStrategy` attempts to change `config.owner` (ownership
    ///         transfer via edit is disallowed; cancel and recreate instead).
    error UnauthorizedAccess(uint256 strategyId, address caller);

    /// @notice Reverts when `config.slippageBps` is outside the valid BPS range [0, 10_000].
    error InvalidSlippage(uint256 slippageBps);

    /// @notice Reverts when `config.tradeAmount` is zero.
    error ZeroTradeAmount();

    /// @notice Reverts when `config.owner` is the zero address.
    error InvalidOwner();

    /// @notice Reverts when `config.sourceVault == config.targetVault` or
    ///         `config.inAsset == config.outAsset`.
    error SameAsset(address asset);

    /// @notice Reverts when `config.interval` is below the contract minimum (1 day).
    error IntervalTooShort(uint256 provided, uint256 minimum);

    /// @notice Reverts when `config.inAssetFeed` or `config.outAssetFeed` is the zero address.
    error InvalidFeedAddress();

    /// @notice Reverts when the current oracle execution price exceeds `config.maxPrice`.
    ///         `executionPrice` is the 1e18-scaled out/in ratio.
    error PriceAboveCeiling(uint256 executionPrice, uint256 maxPrice);

    /// @notice Reverts when the current oracle execution price is below `config.minPrice`.
    ///         `executionPrice` is the 1e18-scaled out/in ratio.
    error PriceBelowFloor(uint256 executionPrice, uint256 minPrice);
}
