// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IDCAStrategyManager} from "../../interfaces/arks/IDCAStrategyManager.sol";

interface IDCAStrategyManagerEvents {
    event StrategyCreated(
        uint256 indexed strategyId,
        IDCAStrategyManager.StrategyConfig config
    );

    event StrategyEdited(
        uint256 indexed strategyId,
        IDCAStrategyManager.StrategyConfig config
    );

    event StrategyPaused(uint256 indexed strategyId, uint256 nextTriggerAt);

    event StrategyResumed(uint256 indexed strategyId, uint256 nextTriggerAt);

    event StrategyCancelled(uint256 indexed strategyId);

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
