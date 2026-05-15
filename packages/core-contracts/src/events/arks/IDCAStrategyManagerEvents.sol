// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

interface IDCAStrategyManagerEvents {
    event StrategyCreated(
        uint256 indexed strategyId,
        address indexed owner,
        bytes32 configCommitment,
        uint256 firstTriggerAt
    );

    event StrategyEdited(
        uint256 indexed strategyId,
        bytes32 oldCommitment,
        bytes32 newCommitment,
        uint256 nextTriggerAt
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

    event ExecutionSkipped(
        uint256 indexed strategyId,
        bytes32 reason,
        bytes extraData
    );
}