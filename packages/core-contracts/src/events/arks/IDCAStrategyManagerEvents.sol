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

    event ExecutionCompleted(
        uint256 indexed strategyId,
        uint256 tradesExecuted,
        uint256 inAmount,
        uint256 outAmount,
        uint256 nextTriggerAt
    );
}
