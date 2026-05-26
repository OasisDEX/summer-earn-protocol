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

    error SwapOutputBelowMinOut(
        uint256 strategyId,
        uint256 minOut,
        uint256 actualOut
    );

    error TerminalStateReached(uint256 strategyId, bytes32 reason);

    error UnauthorizedAccess(uint256 strategyId, address caller);

    error InvalidSlippage(uint256 slippageBps);

    error ZeroTradeAmount();

    error InvalidOwner();

    error SameAsset(address asset);

    error IntervalTooShort(uint256 provided, uint256 minimum);

    error InvalidFeedAddress();

    /// @notice executionPrice is the 1e18-scaled out/in ratio (see _executionPrice).
    error PriceAboveCeiling(uint256 executionPrice, uint256 maxPrice);

    /// @notice executionPrice is the 1e18-scaled out/in ratio (see _executionPrice).
    error PriceBelowFloor(uint256 executionPrice, uint256 minPrice);

}
