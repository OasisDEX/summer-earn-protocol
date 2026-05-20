// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import {IFleetCommander} from "../IFleetCommander.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDCAStrategyManager {
    enum Status {
        ACTIVE,
        PAUSED,
        COMPLETED,
        CANCELLED
    }

    struct StrategyConfig {
        address owner;
        IFleetCommander sourceVault;
        IFleetCommander targetVault;
        IERC20 inAsset;
        IERC20 outAsset;
        address inAssetFeed;
        address outAssetFeed;
        uint256 tradeAmount;
        uint256 interval;
        uint256 slippageBps;
        uint256 maxPrice;
        uint256 minPrice;
        uint256 endDate;
        uint256 maxTrades;
    }

    struct StrategyState {
        uint8 status;
        uint248 tradesExecuted;
        uint256 nextTriggerAt;
        uint256 lastScheduledAt;
    }

    function createStrategy(
        StrategyConfig calldata config
    ) external returns (uint256 strategyId);

    function editStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external;

    function pauseStrategy(uint256 strategyId) external;

    function resumeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external;

    function cancelStrategy(uint256 strategyId) external;

    function executeDCA(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData
    ) external;

    function strategyCommitments(
        uint256 strategyId
    ) external view returns (bytes32);

    function strategyStates(
        uint256 strategyId
    ) external view returns (StrategyState memory);

    function activeCommitments(bytes32 commitment) external view returns (bool);

    function checkUpkeep(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external view returns (bool upkeepNeeded, bytes memory performData);
}
