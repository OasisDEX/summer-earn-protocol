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
    // Fingerprint of every commitment that has ever been registered and not
    // explicitly freed by an edit. Permanent for cancelled/completed strategies
    // — a user wanting an "identical" strategy later will use a future
    // endDate, producing a different hash.
    mapping(bytes32 => bool) private _activeCommitments;

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
        _validateStrategyConfig(config);

        bytes32 commitment = keccak256(abi.encode(config));
        if (_activeCommitments[commitment]) revert DuplicateStrategy();

        strategyId = _nextStrategyId++;
        _activeCommitments[commitment] = true;
        _strategyCommitments[strategyId] = commitment;
        _strategyOwners[strategyId] = config.owner;

        uint256 hourAligned = ((block.timestamp + 3599) / 3600) * 3600;
        _strategyStates[strategyId] = StrategyState({
            status: uint8(Status.ACTIVE),
            tradesExecuted: 0,
            nextTriggerAt: hourAligned + config.interval,
            lastScheduledAt: hourAligned
        });

        emit StrategyCreated(strategyId, config);
    }

    function editStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external {
        if (msg.sender != _strategyOwners[strategyId]) {
            revert UnauthorizedAccess(strategyId, msg.sender);
        }
        _validateStrategyConfig(config);

        bytes32 newCommitment = keccak256(abi.encode(config));
        bytes32 oldCommitment = _strategyCommitments[strategyId];
        if (newCommitment != oldCommitment) {
            if (_activeCommitments[newCommitment]) revert DuplicateStrategy();
            _activeCommitments[oldCommitment] = false;
            _activeCommitments[newCommitment] = true;
            _strategyCommitments[strategyId] = newCommitment;
        }

        StrategyState storage state = _strategyStates[strategyId];
        state.nextTriggerAt = state.lastScheduledAt + config.interval;

        emit StrategyEdited(strategyId, config);
    }

    function _validateStrategyConfig(
        StrategyConfig calldata config
    ) internal view {
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

    function resumeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external {
        if (msg.sender != _strategyOwners[strategyId]) {
            revert UnauthorizedAccess(strategyId, msg.sender);
        }
        if (keccak256(abi.encode(config)) != _strategyCommitments[strategyId]) {
            revert CommitmentMismatch(strategyId);
        }

        StrategyState storage state = _strategyStates[strategyId];
        if (state.status != uint8(Status.PAUSED)) {
            revert StrategyNotActive(strategyId);
        }

        state.status = uint8(Status.ACTIVE);
        state.nextTriggerAt = block.timestamp + config.interval;

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
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData
    ) external onlyKeeper nonReentrant {
        bytes32 storedCommitment = _strategyCommitments[strategyId];
        if (keccak256(abi.encode(config)) != storedCommitment) {
            revert CommitmentMismatch(strategyId);
        }

        StrategyState storage state = _strategyStates[strategyId];
        if (state.status != uint8(Status.ACTIVE)) {
            revert StrategyNotActive(strategyId);
        }

        if (state.tradesExecuted >= config.maxTrades) {
            revert TerminalStateReached(strategyId, "max_trades");
        }
        if (block.timestamp >= config.endDate) {
            revert TerminalStateReached(strategyId, "end_date");
        }

        if (block.timestamp < state.nextTriggerAt) {
            revert ExecutionWindowNotReached(
                strategyId,
                state.nextTriggerAt,
                block.timestamp
            );
        }

        if (ensoData.length == 0) revert EmptyEnsoData(strategyId);

        _executeSwap(strategyId, config, ensoData, state);
    }

    function _executeSwap(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state
    ) internal {
        // _getOraclePrices reverts with OraclePriceZero on raw <= 0.
        (uint256 inPrice, uint256 outPrice) = _getOraclePrices(config);

        if (config.maxPrice > 0 && inPrice > config.maxPrice) {
            revert PriceAboveCeiling(inPrice, config.maxPrice);
        }
        if (config.minPrice > 0 && inPrice < config.minPrice) {
            revert PriceBelowFloor(inPrice, config.minPrice);
        }

        _pullFunds(
            config.owner,
            address(config.sourceVault),
            config.tradeAmount
        );

        _executeSwapCore(
            strategyId,
            config,
            ensoData,
            state,
            inPrice,
            outPrice
        );
    }

    function _executeSwapCore(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state,
        uint256 inPrice,
        uint256 outPrice
    ) internal {
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

        // Proactively flip to COMPLETED after the last valid execution so a
        // follow-up keeper call surfaces StrategyNotActive (clearer than the
        // TerminalStateReached pre-check, which we keep as a backstop).
        if (tradesExecuted >= config.maxTrades) {
            state.status = uint8(Status.COMPLETED);
            emit StrategyCompleted(strategyId, "max_trades");
        } else if (nextTriggerAt >= config.endDate) {
            state.status = uint8(Status.COMPLETED);
            emit StrategyCompleted(strategyId, "end_date");
        }
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

    function activeCommitments(
        bytes32 commitment
    ) external view returns (bool) {
        return _activeCommitments[commitment];
    }

    function checkUpkeep(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        performData = "";
        StrategyState storage state = _strategyStates[strategyId];

        if (state.status != uint8(Status.ACTIVE)) return (false, performData);
        if (block.timestamp < state.nextTriggerAt) return (false, performData);
        if (state.tradesExecuted >= config.maxTrades) {
            return (false, performData);
        }
        if (block.timestamp >= config.endDate) return (false, performData);

        // Oracle simulation only matters when guardrails are set; skipping
        // the staticcall when both bounds are zero saves gas and avoids
        // depending on a working feed for bound-less strategies.
        if (config.maxPrice > 0 || config.minPrice > 0) {
            (uint256 inPrice, ) = _getOraclePrices(config);
            if (config.maxPrice > 0 && inPrice > config.maxPrice) {
                return (false, performData);
            }
            if (config.minPrice > 0 && inPrice < config.minPrice) {
                return (false, performData);
            }
        }

        upkeepNeeded = true;
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
