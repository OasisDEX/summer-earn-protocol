// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface IDCAStrategyManagerErrors {
    error CommitmentMismatch(uint256 strategyId);

    error DuplicateStrategy();

    error StrategyNotActive(uint256 strategyId);

    error ExecutionWindowNotReached(
        uint256 strategyId,
        uint256 nextTriggerAt,
        uint256 blockTimestamp
    );

    error PriceGuardViolation(
        uint256 strategyId,
        uint256 price,
        uint256 limitPrice,
        bool isAbove
    );

    error InsufficientFunds(
        uint256 strategyId,
        uint256 available,
        uint256 required
    );

    error SwapOutputBelowMinOut(
        uint256 strategyId,
        uint256 minOut,
        uint256 actualOut
    );

    error TerminalStateReached(uint256 strategyId, bytes32 reason);

    error UnauthorizedAccess(uint256 strategyId, address caller);

    error InvalidInterval(uint256 interval);

    error InvalidSlippage(uint256 slippageBps);

    error ZeroTradeAmount();

    error SameAsset(address asset);

    error OraclePriceZero();

    error IntervalTooShort(uint256 provided, uint256 minimum);

    error InvalidFeedAddress();

    error EmptyEnsoData(uint256 strategyId);

    error AmountOverflowsUint160(uint256 amount);

    /// @notice `executionPrice` is the 1e18-scaled out/in ratio computed by
    /// the manager from the two Chainlink feeds, NOT the raw inAsset oracle
    /// answer. `maxPrice` is the user-configured ceiling on that ratio.
    error PriceAboveCeiling(uint256 executionPrice, uint256 maxPrice);

    /// @notice `executionPrice` is the 1e18-scaled out/in ratio computed by
    /// the manager from the two Chainlink feeds, NOT the raw inAsset oracle
    /// answer. `minPrice` is the user-configured floor on that ratio.
    error PriceBelowFloor(uint256 executionPrice, uint256 minPrice);
}
