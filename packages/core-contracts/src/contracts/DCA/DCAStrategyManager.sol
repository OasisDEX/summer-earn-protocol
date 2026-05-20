// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IPermit2} from "../../interfaces/permit2/IPermit2.sol";

import {IDCAStrategyManager} from "../../interfaces/arks/IDCAStrategyManager.sol";
import {IDCAStrategyManagerErrors} from "../../errors/arks/IDCAStrategyManagerErrors.sol";
import {IDCAStrategyManagerEvents} from "../../events/arks/IDCAStrategyManagerEvents.sol";
import {IFleetCommander} from "../../interfaces/IFleetCommander.sol";
import {IHarborCommand} from "../../interfaces/IHarborCommand.sol";
import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";

contract DCAStrategyManager is
    IDCAStrategyManager,
    IDCAStrategyManagerErrors,
    IDCAStrategyManagerEvents,
    ReentrancyGuardTransient,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;

    uint256 private constant _BPS = 10000;
    uint256 private constant _MIN_INTERVAL = 7 days;

    uint256 private _nextStrategyId;
    mapping(uint256 => bytes32) private _strategyCommitments;
    mapping(uint256 => StrategyState) private _strategyStates;
    mapping(uint256 => address) private _strategyOwners;

    address public immutable ENSO_ROUTER;
    IHarborCommand public immutable HARBOR_COMMAND;
    IPermit2 public immutable PERMIT2;

    constructor(
        address _accessManager,
        address _ensoRouter,
        address _harborCommand,
        address _permit2
    ) ProtocolAccessManaged(_accessManager) {
        if (_ensoRouter == address(0)) revert InvalidRouterAddress();
        if (_harborCommand == address(0)) revert InvalidHarborCommandAddress();

        ENSO_ROUTER = _ensoRouter;
        HARBOR_COMMAND = IHarborCommand(_harborCommand);
        PERMIT2 = IPermit2(_permit2);
    }

    function createStrategy(
        StrategyConfig calldata config
    ) external returns (uint256 strategyId) {
        if (config.interval < _MIN_INTERVAL) {
            revert IntervalTooShort(config.interval, _MIN_INTERVAL);
        }
        if (config.slippageBps > _BPS) {
            revert InvalidSlippage(config.slippageBps);
        }
        if (config.tradeAmount == 0) revert ZeroTradeAmount();
        if (
            config.inAssetFeed == address(0) ||
            config.outAssetFeed == address(0)
        ) {
            revert InvalidFeedAddress();
        }
        if (
            !HARBOR_COMMAND.activeFleetCommanders(address(config.sourceVault))
        ) {
            revert InvalidSourceVault(address(config.sourceVault));
        }
        if (
            !HARBOR_COMMAND.activeFleetCommanders(address(config.targetVault))
        ) {
            revert InvalidTargetVault(address(config.targetVault));
        }

        strategyId = _nextStrategyId++;
        StrategyConfig memory mutableConfig = config;
        mutableConfig.strategyId = strategyId;

        _strategyCommitments[strategyId] = keccak256(abi.encode(mutableConfig));
        _strategyOwners[strategyId] = config.owner;

        _strategyStates[strategyId] = StrategyState({
            status: uint8(Status.ACTIVE),
            tradesExecuted: 0,
            interval: config.interval,
            nextTriggerAt: block.timestamp + config.interval,
            lastScheduledAt: block.timestamp,
            maxTrades: config.maxTrades,
            endDate: config.endDate
        });

        emit StrategyCreated(strategyId, mutableConfig);
    }

    function editStrategy(StrategyConfig calldata config) external {
        if (msg.sender != _strategyOwners[config.strategyId]) {
            revert UnauthorizedAccess(config.strategyId, msg.sender);
        }
        if (config.interval < _MIN_INTERVAL) {
            revert IntervalTooShort(config.interval, _MIN_INTERVAL);
        }
        if (
            config.inAssetFeed == address(0) ||
            config.outAssetFeed == address(0)
        ) {
            revert InvalidFeedAddress();
        }

        _strategyCommitments[config.strategyId] = keccak256(abi.encode(config));

        StrategyState storage state = _strategyStates[config.strategyId];
        state.interval = config.interval;
        state.maxTrades = config.maxTrades;
        state.endDate = config.endDate;
        state.nextTriggerAt = state.lastScheduledAt + state.interval;

        emit StrategyEdited(config.strategyId, config);
    }

    function pauseStrategy(uint256 strategyId) external {
        StrategyState storage state = _strategyStates[strategyId];

        if (msg.sender != _strategyOwners[strategyId]) {
            revert UnauthorizedAccess(strategyId, msg.sender);
        }
        if (state.status != uint8(Status.ACTIVE)) {
            revert StrategyNotActive(strategyId);
        }

        state.status = uint8(Status.PAUSED);

        emit StrategyPaused(strategyId, state.nextTriggerAt);
    }

    function resumeStrategy(uint256 strategyId) external {
        StrategyState storage state = _strategyStates[strategyId];

        if (msg.sender != _strategyOwners[strategyId]) {
            revert UnauthorizedAccess(strategyId, msg.sender);
        }
        if (state.status != uint8(Status.PAUSED)) {
            revert StrategyNotActive(strategyId);
        }

        state.status = uint8(Status.ACTIVE);
        state.nextTriggerAt = block.timestamp + state.interval;

        emit StrategyResumed(strategyId, state.nextTriggerAt);
    }

    function cancelStrategy(uint256 strategyId) external {
        StrategyState storage state = _strategyStates[strategyId];

        if (msg.sender != _strategyOwners[strategyId]) {
            revert UnauthorizedAccess(strategyId, msg.sender);
        }
        if (state.status == uint8(Status.CANCELLED)) {
            revert StrategyNotActive(strategyId);
        }

        state.status = uint8(Status.CANCELLED);

        emit StrategyCancelled(strategyId);
    }

    function executeDCA(
        StrategyConfig calldata config,
        bytes calldata ensoData
    ) external onlyKeeper nonReentrant {
        bytes32 storedCommitment = _strategyCommitments[config.strategyId];
        if (keccak256(abi.encode(config)) != storedCommitment) {
            revert CommitmentMismatch(config.strategyId);
        }

        StrategyState storage state = _strategyStates[config.strategyId];
        if (state.status != uint8(Status.ACTIVE)) {
            revert StrategyNotActive(config.strategyId);
        }

        if (
            state.tradesExecuted >= config.maxTrades ||
            block.timestamp >= config.endDate
        ) {
            state.status = uint8(Status.COMPLETED);
            emit ExecutionSkipped(
                config.strategyId,
                "terminal",
                abi.encode("max trades or end date reached")
            );
            return;
        }

        if (block.timestamp < state.nextTriggerAt) {
            revert ExecutionWindowNotReached(
                config.strategyId,
                state.nextTriggerAt,
                block.timestamp
            );
        }

        if (ensoData.length == 0) revert EmptyEnsoData(config.strategyId);

        _executeSwap(config, ensoData, state);
    }

    function _executeSwap(
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state
    ) internal {
        (uint256 inPrice, uint256 outPrice) = _getOraclePrices(config);

        if (inPrice == 0 || outPrice == 0) {
            _skipWithAdvance(state, config.strategyId, "oracle_price_zero", "");
            return;
        }

        if (config.maxPrice > 0 && inPrice > config.maxPrice) {
            _skipWithAdvance(
                state,
                config.strategyId,
                "price_ceiling",
                abi.encode(inPrice, config.maxPrice)
            );
            return;
        }

        if (config.minPrice > 0 && inPrice < config.minPrice) {
            _skipWithAdvance(
                state,
                config.strategyId,
                "price_floor",
                abi.encode(inPrice, config.minPrice)
            );
            return;
        }

        _pullFunds(
            config.owner,
            address(config.sourceVault),
            config.tradeAmount
        );

        _executeSwapCore(config, ensoData, state, inPrice, outPrice);
    }

    function _executeSwapCore(
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state,
        uint256 inPrice,
        uint256 outPrice
    ) internal {
        uint256 strategyId = config.strategyId;

        // Effects: write state before any external interaction.
        uint256 nextTriggerAt = block.timestamp + config.interval;
        state.tradesExecuted += 1;
        state.lastScheduledAt = block.timestamp;
        state.nextTriggerAt = nextTriggerAt;
        uint248 tradesExecuted = state.tradesExecuted;

        uint256 targetSharesBefore = IERC20(address(config.targetVault))
            .balanceOf(address(this));

        // Interactions: approve, swap, reset allowance.
        IERC20(address(config.sourceVault)).forceApprove(
            ENSO_ROUTER,
            config.tradeAmount
        );
        {
            (bool success, ) = ENSO_ROUTER.call(ensoData);
            if (!success) revert SwapFailed(strategyId);
        }
        IERC20(address(config.sourceVault)).forceApprove(ENSO_ROUTER, 0);

        uint256 swappedAmount = IERC20(address(config.targetVault)).balanceOf(
            address(this)
        ) - targetSharesBefore;

        uint256 minOut = _calculateMinOut(config, inPrice, outPrice);
        if (swappedAmount < minOut) {
            revert SwapOutputBelowMinOut(strategyId, minOut, swappedAmount);
        }

        IERC20(address(config.targetVault)).safeTransfer(
            config.owner,
            swappedAmount
        );

        emit ExecutionCompleted(
            strategyId,
            tradesExecuted,
            config.tradeAmount,
            swappedAmount,
            nextTriggerAt
        );
    }

    function _skipWithAdvance(
        StrategyState storage state,
        uint256 strategyId,
        bytes32 reason,
        bytes memory extraData
    ) internal {
        state.lastScheduledAt = block.timestamp;
        state.nextTriggerAt = block.timestamp + state.interval;
        emit ExecutionSkipped(strategyId, reason, extraData);
    }

    function strategyCommitments(
        uint256 strategyId
    ) external view returns (bytes32) {
        return _strategyCommitments[strategyId];
    }

    function strategyStates(
        uint256 strategyId
    ) external view returns (StrategyState memory) {
        return _strategyStates[strategyId];
    }

    function checkUpkeep(
        uint256 strategyId
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        StrategyState storage state = _strategyStates[strategyId];
        upkeepNeeded =
            state.status == uint8(Status.ACTIVE) &&
            block.timestamp >= state.nextTriggerAt &&
            state.tradesExecuted < state.maxTrades &&
            block.timestamp < state.endDate;
        performData = "";
    }

    function _pullFunds(
        address owner,
        address sourceVault,
        uint256 amount
    ) internal returns (uint256) {
        if (amount > type(uint160).max) revert AmountOverflowsUint160(amount);
        PERMIT2.transferFrom(
            owner,
            address(this),
            uint160(amount),
            sourceVault
        );
        return amount;
    }

    function _getOraclePrices(
        StrategyConfig calldata config
    ) internal view returns (uint256 inPrice, uint256 outPrice) {
        (, int256 inRaw, , , ) = AggregatorV3Interface(config.inAssetFeed)
            .latestRoundData();
        if (inRaw <= 0) revert OraclePriceZero();
        (, int256 outRaw, , , ) = AggregatorV3Interface(config.outAssetFeed)
            .latestRoundData();
        if (outRaw <= 0) revert OraclePriceZero();
        inPrice = uint256(inRaw);
        outPrice = uint256(outRaw);
    }

    function _calculateMinOut(
        StrategyConfig calldata config,
        uint256 inPrice,
        uint256 outPrice
    ) internal view returns (uint256 minOut) {
        uint256 inAssets = config.sourceVault.convertToAssets(
            config.tradeAmount
        );

        uint8 inAssetDec = IERC20Metadata(address(config.inAsset)).decimals();
        uint8 outAssetDec = IERC20Metadata(address(config.outAsset)).decimals();
        uint8 inOracleDec = AggregatorV3Interface(config.inAssetFeed)
            .decimals();
        uint8 outOracleDec = AggregatorV3Interface(config.outAssetFeed)
            .decimals();

        uint256 numScale = 10 ** (uint256(outOracleDec) + uint256(outAssetDec));
        uint256 denScale = 10 ** (uint256(inOracleDec) + uint256(inAssetDec));

        uint256 expectedOutAssets = Math.mulDiv(
            inAssets * inPrice,
            numScale,
            outPrice * denScale
        );

        uint256 expectedOutShares = config.targetVault.previewDeposit(
            expectedOutAssets
        );

        minOut = (expectedOutShares * (_BPS - config.slippageBps)) / _BPS;
    }

    error InvalidRouterAddress();
    error InvalidHarborCommandAddress();
    error InvalidSourceVault(address vault);
    error InvalidTargetVault(address vault);
    error SwapFailed(uint256 strategyId);
}
