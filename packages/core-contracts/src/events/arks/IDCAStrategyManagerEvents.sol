// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IDCAStrategyManager} from "../../interfaces/arks/IDCAStrategyManager.sol";

/**
 * @title IDCAStrategyManagerEvents
 * @notice Events emitted by the DCA (dollar-cost-averaging) strategy manager
 */
interface IDCAStrategyManagerEvents {
    /**
     * @notice Emitted when a new DCA strategy is created
     * @param strategyId The identifier of the newly created strategy
     * @param config The configuration of the created strategy
     */
    event StrategyCreated(
        uint256 indexed strategyId,
        IDCAStrategyManager.StrategyConfig config
    );

    /**
     * @notice Emitted when an existing DCA strategy's configuration is edited
     * @param strategyId The identifier of the edited strategy
     * @param config The updated configuration of the strategy
     */
    event StrategyEdited(
        uint256 indexed strategyId,
        IDCAStrategyManager.StrategyConfig config
    );

    /**
     * @notice Emitted when a DCA strategy is paused
     * @param strategyId The identifier of the paused strategy
     * @param nextTriggerAt The timestamp at which the strategy would next trigger
     */
    event StrategyPaused(uint256 indexed strategyId, uint256 nextTriggerAt);

    /**
     * @notice Emitted when a paused DCA strategy is resumed
     * @param strategyId The identifier of the resumed strategy
     * @param nextTriggerAt The updated timestamp at which the strategy will next trigger
     */
    event StrategyResumed(uint256 indexed strategyId, uint256 nextTriggerAt);

    /**
     * @notice Emitted when a DCA strategy is cancelled
     * @param strategyId The identifier of the cancelled strategy
     */
    event StrategyCancelled(uint256 indexed strategyId);

    /**
     * @notice Emitted when a DCA strategy has completed
     * @param strategyId The identifier of the completed strategy
     * @param reason An encoded reason describing why the strategy completed
     */
    event StrategyCompleted(uint256 indexed strategyId, bytes32 reason);

    /**
     * @notice Emitted after each successful DCA execution.
     * @param strategyId The strategy that executed.
     * @param tradesExecuted Post-increment trade counter (1-based).
     * @param inShares Source-vault shares pulled from the owner (config.tradeAmount).
     * @param outShares Target-vault shares delivered to the owner.
     * @param inAssets Underlying in-asset amount represented by `inShares` at the moment of the trade
     *                 (`sourceVault.convertToAssets(inShares)`).
     * @param outAssets Underlying out-asset amount represented by `outShares` at the moment of the trade
     *                  (`targetVault.convertToAssets(outShares)`).
     * @param nextTriggerAt Updated `_strategyStates[strategyId].nextTriggerAt`.
     */
    event ExecutionCompleted(
        uint256 indexed strategyId,
        uint256 tradesExecuted,
        uint256 inShares,
        uint256 outShares,
        uint256 inAssets,
        uint256 outAssets,
        uint256 nextTriggerAt
    );
}
