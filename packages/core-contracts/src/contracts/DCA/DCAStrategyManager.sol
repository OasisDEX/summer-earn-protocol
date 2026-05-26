// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {Permit2Consumer} from "./Permit2Consumer.sol";
import {EnsoRouterSwapper} from "./EnsoRouterSwapper.sol";
import {HarborCommandConsumer} from "./HarborCommandConsumer.sol";
import {ChainlinkPriceConsumer} from "./ChainlinkPriceConsumer.sol";
import {BPS, BPS_100} from "@summerfi/percentage-solidity/contracts/BPS.sol";
import {BpsUtils} from "@summerfi/percentage-solidity/contracts/BpsUtils.sol";

import {IDCAStrategyManager} from "../../interfaces/arks/IDCAStrategyManager.sol";
import {IDCAStrategyManagerErrors} from "../../errors/arks/IDCAStrategyManagerErrors.sol";
import {IDCAStrategyManagerEvents} from "../../events/arks/IDCAStrategyManagerEvents.sol";
import {IFleetCommander} from "../../interfaces/IFleetCommander.sol";
import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";

contract DCAStrategyManager is
    IDCAStrategyManager,
    IDCAStrategyManagerErrors,
    IDCAStrategyManagerEvents,
    ReentrancyGuardTransient,
    ProtocolAccessManaged,
    Permit2Consumer,
    EnsoRouterSwapper,
    HarborCommandConsumer,
    ChainlinkPriceConsumer
{
    using SafeERC20 for IERC20;
    using BpsUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant _MIN_INTERVAL = 1 days;
    uint256 private constant _PRICE_PRECISION = 1e18;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIALES
    //////////////////////////////////////////////////////////////*/
    uint256 private _nextStrategyId;
    mapping(uint256 strategyId => bytes32 commitmentHash)
        private _strategyCommitments;
    mapping(uint256 strategyId => StrategyState state) private _strategyStates;
    mapping(bytes32 commitmentHash => bool) private _activeCommitments;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _accessManager,
        address _ensoRouter,
        address _harborCommand,
        address _permit2
    )
        ProtocolAccessManaged(_accessManager)
        Permit2Consumer(_permit2)
        EnsoRouterSwapper(_ensoRouter)
        HarborCommandConsumer(_harborCommand)
    {}

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reverts if `config` does not match the stored commitment for
    ///      `strategyId` or if the caller is not `config.owner`.
    modifier onlyStrategyOwner(
        uint256 strategyId,
        StrategyConfig calldata config
    ) {
        if (_commitmentHash(config) != _strategyCommitments[strategyId]) {
            revert CommitmentMismatch(strategyId);
        }
        if (_msgSender() != config.owner) {
            revert UnauthorizedAccess(strategyId, _msgSender());
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              STRATEGY MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    function createStrategy(
        StrategyConfig calldata config
    )
        external
        onlyActiveFleetCommander(address(config.sourceVault), "source")
        onlyActiveFleetCommander(address(config.targetVault), "target")
        returns (uint256 strategyId)
    {
        _validateStrategyConfig(config);

        bytes32 commitment = _commitmentHash(config);
        if (_activeCommitments[commitment]) revert DuplicateStrategy();

        strategyId = _nextStrategyId++;
        _activeCommitments[commitment] = true;
        _strategyCommitments[strategyId] = commitment;

        uint256 hourAligned = _hourAlignedTimestamp();
        _strategyStates[strategyId] = StrategyState({
            status: Status.ACTIVE,
            tradesExecuted: 0,
            nextTriggerAt: hourAligned + config.interval,
            lastScheduledAt: hourAligned
        });

        emit StrategyCreated(strategyId, config);
    }

    function editStrategy(
        uint256 strategyId,
        StrategyConfig calldata oldConfig,
        StrategyConfig calldata newConfig
    )
        external
        onlyStrategyOwner(strategyId, oldConfig)
        onlyActiveFleetCommander(address(newConfig.sourceVault), "source")
        onlyActiveFleetCommander(address(newConfig.targetVault), "target")
    {
        // Ownership transfer via edit is disallowed — the commitment is the
        // ownership proof, so changing config.owner would silently re-key
        // authorization. Force-cancel + recreate instead.
        if (newConfig.owner != oldConfig.owner) {
            revert UnauthorizedAccess(strategyId, _msgSender());
        }
        _validateStrategyConfig(newConfig);

        bytes32 oldCommitment = _commitmentHash(oldConfig);
        bytes32 newCommitment = _commitmentHash(newConfig);
        if (_activeCommitments[newCommitment]) revert DuplicateStrategy();

        if (newCommitment != oldCommitment) {
            _activeCommitments[oldCommitment] = false;
            _activeCommitments[newCommitment] = true;
            _strategyCommitments[strategyId] = newCommitment;
        }

        StrategyState storage state = _strategyState(strategyId);
        state.nextTriggerAt = state.lastScheduledAt + newConfig.interval;

        emit StrategyEdited(strategyId, newConfig);
    }

    function pauseStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external onlyStrategyOwner(strategyId, config) {
        StrategyState storage state = _strategyState(strategyId);
        if (state.status != Status.ACTIVE) {
            revert StrategyNotActive(strategyId);
        }

        state.status = Status.PAUSED;

        emit StrategyPaused(strategyId, state.nextTriggerAt);
    }

    function resumeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external onlyStrategyOwner(strategyId, config) {
        StrategyState storage state = _strategyState(strategyId);
        if (state.status != Status.PAUSED) {
            revert StrategyNotActive(strategyId);
        }

        state.status = Status.ACTIVE;
        state.nextTriggerAt = block.timestamp + config.interval;

        emit StrategyResumed(strategyId, state.nextTriggerAt);
    }

    function cancelStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external onlyStrategyOwner(strategyId, config) {
        StrategyState storage state = _strategyState(strategyId);
        if (state.status == Status.CANCELLED) {
            revert StrategyNotActive(strategyId);
        }

        state.status = Status.CANCELLED;

        emit StrategyCancelled(strategyId);
    }

    function executeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData
    ) external onlyKeeper nonReentrant {
        bytes32 storedCommitment = _strategyCommitments[strategyId];
        if (_commitmentHash(config) != storedCommitment) {
            revert CommitmentMismatch(strategyId);
        }

        StrategyState storage state = _strategyState(strategyId);
        if (state.status != Status.ACTIVE) {
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

        _executeSwap(strategyId, config, ensoData, state);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
        StrategyState storage state = _strategyState(strategyId);

        if (state.status != Status.ACTIVE) return (false, performData);
        if (block.timestamp < state.nextTriggerAt) return (false, performData);
        if (state.tradesExecuted >= config.maxTrades) {
            return (false, performData);
        }
        if (block.timestamp >= config.endDate) return (false, performData);

        if (config.maxPrice > 0 || config.minPrice > 0) {
            (uint256 inPrice, uint256 outPrice) = _getOraclePrices(config);
            uint256 executionPrice = _executionPrice(config, inPrice, outPrice);
            if (config.maxPrice > 0 && executionPrice > config.maxPrice) {
                return (false, performData);
            }
            if (config.minPrice > 0 && executionPrice < config.minPrice) {
                return (false, performData);
            }
        }

        upkeepNeeded = true;
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _strategyState(
        uint256 strategyId
    ) internal view returns (StrategyState storage) {
        return _strategyStates[strategyId];
    }

    /// @dev Rounds `block.timestamp` up to the next whole hour boundary.
    function _hourAlignedTimestamp() internal view returns (uint256) {
        return ((block.timestamp + 3599) / 3600) * 3600;
    }

    function _commitmentHash(
        StrategyConfig calldata config
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(config));
    }

    function _validateStrategyConfig(
        StrategyConfig calldata config
    ) internal view {
        if (config.interval < _MIN_INTERVAL) {
            revert IntervalTooShort(config.interval, _MIN_INTERVAL);
        }
        if (!BpsUtils.isBpsInRange(BPS.wrap(config.slippageBps))) {
            revert InvalidSlippage(config.slippageBps);
        }
        if (config.tradeAmount == 0) revert ZeroTradeAmount();
        if (
            config.inAssetFeed == address(0) ||
            config.outAssetFeed == address(0)
        ) {
            revert InvalidFeedAddress();
        }
    }

    function _executeSwap(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state
    ) internal {
        // _getOraclePrices reverts with OraclePriceZero on raw <= 0.
        (uint256 inPrice, uint256 outPrice) = _getOraclePrices(config);

        uint256 executionPrice = _executionPrice(config, inPrice, outPrice);
        if (config.maxPrice > 0 && executionPrice > config.maxPrice) {
            revert PriceAboveCeiling(executionPrice, config.maxPrice);
        }
        if (config.minPrice > 0 && executionPrice < config.minPrice) {
            revert PriceBelowFloor(executionPrice, config.minPrice);
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

        // Interactions: approve, swap, reset allowance via Enso router.
        _ensoSwap(address(config.sourceVault), config.tradeAmount, ensoData);

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

        if (tradesExecuted >= config.maxTrades) {
            state.status = Status.COMPLETED;
            emit StrategyCompleted(strategyId, "max_trades");
        } else if (nextTriggerAt >= config.endDate) {
            state.status = Status.COMPLETED;
            emit StrategyCompleted(strategyId, "end_date");
        }
    }

    function _getOraclePrices(
        StrategyConfig calldata config
    ) internal view returns (uint256 inPrice, uint256 outPrice) {
        inPrice = _getPrice(config.inAssetFeed);
        outPrice = _getPrice(config.outAssetFeed);
    }

    /// @dev 1e18-scaled out/in execution price (inAsset units per 1 outAsset).
    function _executionPrice(
        StrategyConfig calldata config,
        uint256 inPrice,
        uint256 outPrice
    ) internal view returns (uint256) {
        uint8 inOracleDec = AggregatorV3Interface(config.inAssetFeed)
            .decimals();
        uint8 outOracleDec = AggregatorV3Interface(config.outAssetFeed)
            .decimals();
        return
            Math.mulDiv(
                outPrice,
                10 ** uint256(inOracleDec) * _PRICE_PRECISION,
                inPrice * 10 ** uint256(outOracleDec)
            );
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

        minOut = expectedOutShares.subtractBps(BPS.wrap(config.slippageBps));
    }
}
