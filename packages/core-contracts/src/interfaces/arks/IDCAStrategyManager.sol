// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IFleetCommander} from "../IFleetCommander.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDCAStrategyManager {
    /**
     * @notice Lifecycle states of a DCA strategy.
     */
    enum Status {
        /// @notice Strategy is live and eligible for keeper execution.
        ACTIVE,
        /// @notice Strategy is temporarily halted by the owner; no executions occur.
        PAUSED,
        /// @notice Terminal — strategy ran to completion (max trades or end date reached).
        COMPLETED,
        /// @notice Terminal — strategy was manually cancelled by the owner.
        CANCELLED
    }

    /**
     * @notice Immutable user-defined parameters that define a DCA strategy.
     * @dev The struct is ABI-encoded and hashed to produce the commitment stored
     *      on-chain. Any field change produces a different commitment, which
     *      acts as both a replay-protection key and an ownership proof.
     */
    struct StrategyConfig {
        /// @notice Address authorised to manage (edit / pause / resume / cancel) this strategy.
        address owner;
        /// @notice FleetCommander from which `tradeAmount` shares are pulled on each execution.
        IFleetCommander sourceVault;
        /// @notice FleetCommander into which the swap proceeds are deposited on each execution.
        IFleetCommander targetVault;
        /// @notice Underlying asset of `sourceVault`; used for Chainlink price lookups.
        IERC20 inAsset;
        /// @notice Underlying asset of `targetVault`; used for Chainlink price lookups.
        IERC20 outAsset;
        /// @notice Chainlink AggregatorV3 feed address for `inAsset` (e.g. USDC / USD).
        address inAssetFeed;
        /// @notice Chainlink AggregatorV3 feed address for `outAsset` (e.g. ETH / USD).
        address outAssetFeed;
        /// @notice Number of `sourceVault` shares sold on each execution.
        uint256 tradeAmount;
        /// @notice Minimum seconds that must elapse between executions. Must be ≥ 1 day.
        uint256 interval;
        /// @notice Maximum acceptable slippage expressed in basis points (0–10 000).
        uint256 slippageBps;
        /// @notice Ceiling on the out/in execution-price ratio scaled to ChainlinkOracleUtils.PRECISION. 0 = no ceiling.
        uint256 maxPrice;
        /// @notice Floor on the out/in execution-price ratio scaled to ChainlinkOracleUtils.PRECISION. 0 = no floor.
        uint256 minPrice;
        /// @notice Unix timestamp after which no further executions are permitted.
        uint256 endDate;
        /// @notice Maximum number of executions before the strategy auto-completes.
        ///         Must be >= 1; zero is rejected at validation.
        uint256 maxTrades;
    }

    /**
     * @notice Mutable runtime state of a DCA strategy.
     */
    struct StrategyState {
        /// @notice Current lifecycle status.
        Status status;
        /// @notice Number of successful executions completed so far.
        uint248 tradesExecuted;
        /// @notice Earliest Unix timestamp at which the next execution may occur.
        uint256 nextTriggerAt;
        /// @notice Timestamp at which the last execution was scheduled; used to
        ///         recalculate `nextTriggerAt` when the interval is changed via `editStrategy`.
        uint256 lastScheduledAt;
    }

    /**
     * @notice Creates a new DCA strategy with the given configuration.
     * @dev Assigns a monotonically-increasing strategy ID. The initial
     *      `nextTriggerAt` is set to the next whole-hour boundary plus
     *      `config.interval`, reducing keeper scheduling fragmentation.
     *      Reverts with `DuplicateStrategy` if an identical active commitment
     *      already exists.
     * @param config Fully populated strategy configuration.
     * @return strategyId The newly assigned strategy identifier (0-based, sequential).
     */
    function createStrategy(
        StrategyConfig calldata config
    ) external returns (uint256 strategyId);

    /**
     * @notice Deposits `assetAmount` of `config.inAsset` into `config.sourceVault`
     *         on behalf of the caller, then creates a DCA strategy in the same
     *         transaction.
     * @dev The deposit goes through the manager only momentarily — the caller
     *      pre-approves the manager for `config.inAsset`, the manager pulls the
     *      assets, approves `config.sourceVault`, and calls
     *      `sourceVault.deposit(assetAmount, msg.sender)` so the resulting
     *      source-vault shares land in the caller's wallet directly.
     *      The Permit2 sub-allowance for future keeper-driven pulls must still
     *      be granted by the caller separately (`Permit2.approve` or `permit`).
     *      Reverts with `ZeroDeposit` if `assetAmount == 0`.
     *      All `createStrategy` validations also apply.
     * @param config Fully populated strategy configuration.
     * @param assetAmount Underlying-asset amount to deposit into `config.sourceVault`
     *                    (denominated in `config.inAsset` native decimals).
     * @return strategyId The newly assigned strategy identifier.
     */
    function depositAndCreate(
        StrategyConfig calldata config,
        uint256 assetAmount
    ) external returns (uint256 strategyId);

    /**
     * @notice Updates a strategy's configuration in place.
     * @dev The old commitment hash is freed and the new one is registered
     *      atomically. `nextTriggerAt` is recalculated from `lastScheduledAt`
     *      using the new interval.
     *      Ownership transfer via edit is disallowed; cancel and recreate instead.
     *      Reverts with `CommitmentMismatch` if `oldConfig` does not match the stored commitment.
     *      Reverts with `UnauthorizedAccess` if the caller is not `oldConfig.owner` or
     *      if `newConfig.owner != oldConfig.owner`.
     *      Reverts with `DuplicateStrategy` if `newConfig` collides with an existing active commitment.
     * @param strategyId Identifier of the strategy to edit.
     * @param oldConfig Exact current configuration (must hash to the stored commitment).
     * @param newConfig Desired replacement configuration (must pass validation).
     */
    function editStrategy(
        uint256 strategyId,
        StrategyConfig calldata oldConfig,
        StrategyConfig calldata newConfig
    ) external;

    /**
     * @notice Pauses an active strategy, preventing keeper executions until resumed.
     * @dev Reverts with `CommitmentMismatch` if `config` does not match the stored commitment.
     *      Reverts with `UnauthorizedAccess` if the caller is not `config.owner`.
     *      Reverts with `StrategyNotActive` if the strategy is not currently ACTIVE.
     * @param strategyId Identifier of the strategy to pause.
     * @param config Exact current configuration (commitment + ownership proof).
     */
    function pauseStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external;

    /**
     * @notice Resumes a paused strategy and resets `nextTriggerAt` to now + interval.
     * @dev Reverts with `CommitmentMismatch` if `config` does not match the stored commitment.
     *      Reverts with `UnauthorizedAccess` if the caller is not `config.owner`.
     *      Reverts with `StrategyNotActive` if the strategy is not currently PAUSED.
     * @param strategyId Identifier of the strategy to resume.
     * @param config Exact current configuration (commitment + ownership proof).
     */
    function resumeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external;

    /**
     * @notice Permanently cancels a strategy.
     * @dev Terminal state — the commitment slot is NOT freed, so an identical
     *      config cannot be re-registered without mutating at least one field.
     *      Reverts with `CommitmentMismatch` if `config` does not match the stored commitment.
     *      Reverts with `UnauthorizedAccess` if the caller is not `config.owner`.
     *      Reverts with `StrategyNotActive` if the strategy is already CANCELLED.
     * @param strategyId Identifier of the strategy to cancel.
     * @param config Exact current configuration (commitment + ownership proof).
     */
    function cancelStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external;

    /**
     * @notice Executes a single DCA trade for a strategy.
     * @dev Callable only by a permissioned keeper. Pulls `config.tradeAmount`
     *      source-vault shares from the owner via Permit2 AllowanceTransfer,
     *      routes them through the Enso aggregator, and forwards the resulting
     *      target-vault shares to the owner — all in a single transaction.
     *      Advances `nextTriggerAt` and increments `tradesExecuted`. Transitions
     *      the strategy to COMPLETED when `maxTrades` is reached or
     *      `nextTriggerAt >= endDate` after the trade.
     *      If `maxTrades` or `endDate` is already exceeded on entry, transitions
     *      the strategy to COMPLETED and emits `StrategyCompleted` without
     *      reverting (no trade is performed).
     *      Reverts with `CommitmentMismatch` if `config` does not match the stored commitment.
     *      Reverts with `StrategyNotActive` if the strategy is not ACTIVE.
     *      Reverts with `ExecutionWindowNotReached` if called before `nextTriggerAt`.
     * @param strategyId Identifier of the strategy to execute.
     * @param config Exact current configuration (commitment proof).
     * @param ensoData Calldata forwarded verbatim to the Enso router.
     */
    function executeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData
    ) external;

    /**
     * @notice Returns the stored commitment hash for a strategy.
     * @param strategyId Strategy to query.
     * @return keccak256(abi.encode(config)) at the time of the last create or edit.
     */
    function strategyCommitments(
        uint256 strategyId
    ) external view returns (bytes32);

    /**
     * @notice Returns a memory copy of the current runtime state for a strategy.
     * @param strategyId Strategy to query.
     * @return Current `StrategyState` (status, tradesExecuted, nextTriggerAt, lastScheduledAt).
     */
    function strategyStates(
        uint256 strategyId
    ) external view returns (StrategyState memory);

    /**
     * @notice Returns whether a commitment hash is currently registered as active.
     * @dev Active commitments cannot be reused by `createStrategy` or `editStrategy`
     *      until freed by a successful edit away from this config. Terminal states
     *      (CANCELLED / COMPLETED) do NOT free their commitment.
     * @param commitment Hash to query.
     * @return `true` if the hash is registered and has not been freed.
     */
    function activeCommitments(bytes32 commitment) external view returns (bool);

    /**
     * @notice Off-chain keeper polling function — returns whether a strategy is
     *         ready for execution and what data to supply.
     * @dev Returns `(false, "")` when any of the following hold:
     *      the strategy is not ACTIVE, the execution window has not been reached,
     *      `maxTrades` is exhausted, `endDate` has passed, or the oracle execution
     *      price falls outside `[minPrice, maxPrice]`.
     *      `performData` is always empty — the keeper supplies `ensoData` off-chain.
     * @param strategyId Strategy to check.
     * @param config Exact current configuration.
     * @return upkeepNeeded `true` if a keeper call to `executeStrategy` would not revert on preconditions.
     * @return performData Always empty bytes; Enso calldata is determined off-chain by the keeper.
     */
    function checkUpkeep(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external view returns (bool upkeepNeeded, bytes memory performData);
}
