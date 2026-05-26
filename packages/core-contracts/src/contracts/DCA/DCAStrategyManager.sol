// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {Permit2Consumer} from "../../utils/Permit2Consumer.sol";
import {EnsoRouterSwapper} from "../../utils/EnsoRouterSwapper.sol";
import {HarborCommandConsumer} from "../../utils/HarborCommandConsumer.sol";
import {ChainlinkOracleUtils, ChainlinkOraclePrice} from "../../utils/ChainlinkOracleUtils.sol";
import {BPS, BPS_100} from "@summerfi/percentage-solidity/contracts/BPS.sol";
import {BpsUtils} from "@summerfi/percentage-solidity/contracts/BpsUtils.sol";

import {IDCAStrategyManager} from "../../interfaces/arks/IDCAStrategyManager.sol";
import {IDCAStrategyManagerErrors} from "../../errors/arks/IDCAStrategyManagerErrors.sol";
import {IDCAStrategyManagerEvents} from "../../events/arks/IDCAStrategyManagerEvents.sol";
import {IFleetCommander} from "../../interfaces/IFleetCommander.sol";

/**
 * @title DCAStrategyManager
 * @notice Manages user-owned dollar-cost-averaging strategies executed by a
 *         permissioned keeper.
 *
 * @dev The contract holds no funds. Each execution pulls exactly `tradeAmount`
 *      source-vault shares from the strategy owner via Permit2 AllowanceTransfer,
 *      routes them through the Enso aggregator, deposits the proceeds into the
 *      target FleetCommander, and forwards the resulting shares to the owner —
 *      all in a single atomic transaction.
 *
 *      Ownership is proven statelessly: every owner-gated function accepts the
 *      full `StrategyConfig` calldata and verifies that its keccak256 hash
 *      matches the stored commitment, then checks `msg.sender == config.owner`.
 *      There is no separate `_strategyOwners` mapping.
 */
contract DCAStrategyManager is
    IDCAStrategyManager,
    IDCAStrategyManagerErrors,
    IDCAStrategyManagerEvents,
    ReentrancyGuardTransient,
    ProtocolAccessManaged,
    Permit2Consumer,
    EnsoRouterSwapper,
    HarborCommandConsumer
{
    using SafeERC20 for IERC20;
    using BpsUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum allowed interval between executions (1 day).
    uint256 private constant _MIN_INTERVAL = 1 days;

    /// @notice Maximum allowed slippage in BPS (50%).
    BPS private constant _MAX_SLIPPAGE_BPS = BPS.wrap(5000);

    /*//////////////////////////////////////////////////////////////
                              STATE VARIALES
    //////////////////////////////////////////////////////////////*/

    /// @notice Monotonically-increasing counter used to assign the next strategy ID.
    uint256 private _nextStrategyId;

    /// @notice Maps each strategy ID to its current commitment hash (keccak256 of its config).
    mapping(uint256 strategyId => bytes32 commitmentHash)
        public strategyCommitments;

    /// @notice Maps each strategy ID to its mutable runtime state.
    mapping(uint256 strategyId => StrategyState state) private _strategyStates;

    /// @notice Tracks which commitment hashes are currently active, preventing duplicate strategies.
    mapping(bytes32 commitmentHash => bool) public activeCommitments;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _accessManager Address of the ProtocolAccessManager (governs keeper roles).
     * @param _ensoRouter Address of the Enso aggregator router used for all swaps.
     * @param _harborCommand Address of the HarborCommand registry for FleetCommander validation.
     * @param _permit2 Address of the Uniswap Permit2 singleton used for allowance pulls.
     */
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
    {
        // Empty on purpose
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Reverts if `config` does not match the stored commitment for
     *      `strategyId` or if the caller is not `config.owner`.
     */
    modifier onlyStrategyOwner(
        uint256 strategyId,
        StrategyConfig calldata config
    ) {
        if (_commitmentHash(config) != strategyCommitments[strategyId]) {
            revert CommitmentMismatch(strategyId);
        }
        if (_msgSender() != config.owner) {
            revert UnauthorizedAccess(strategyId, _msgSender());
        }
        _;
    }

    /**
     * @dev Reverts if the caller is not `config.owner`.
     */
    modifier ownerOnlySender(StrategyConfig calldata config) {
        if (_msgSender() != config.owner) {
            revert UnauthorizedOwner(config.owner, _msgSender());
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              STRATEGY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function createStrategy(
        StrategyConfig calldata config
    )
        external
        ownerOnlySender(config)
        onlyActiveFleetCommander(config.sourceVault, "source")
        onlyActiveFleetCommander(config.targetVault, "target")
        returns (uint256 strategyId)
    {
        _validateStrategyConfig(config);

        bytes32 commitment = _commitmentHash(config);
        if (activeCommitments[commitment]) revert DuplicateStrategy();

        strategyId = _nextStrategyId++;
        activeCommitments[commitment] = true;
        strategyCommitments[strategyId] = commitment;

        uint256 hourAligned = _hourAlignedTimestamp();
        _strategyStates[strategyId] = StrategyState({
            status: Status.ACTIVE,
            tradesExecuted: 0,
            nextTriggerAt: hourAligned + config.interval,
            lastScheduledAt: hourAligned
        });

        emit StrategyCreated(strategyId, config);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function editStrategy(
        uint256 strategyId,
        StrategyConfig calldata oldConfig,
        StrategyConfig calldata newConfig
    )
        external
        onlyStrategyOwner(strategyId, oldConfig)
        onlyActiveFleetCommander(newConfig.sourceVault, "source")
        onlyActiveFleetCommander(newConfig.targetVault, "target")
    {
        StrategyState storage state = _strategyStates[strategyId];

        if (
            state.status == Status.CANCELLED || state.status == Status.COMPLETED
        ) {
            revert StrategyNotActive(strategyId);
        }

        // Ownership transfer via edit is disallowed — the commitment is the
        // ownership proof, so changing config.owner would silently re-key
        // authorization. Force-cancel + recreate instead.
        if (newConfig.owner != oldConfig.owner) {
            revert UnauthorizedAccess(strategyId, _msgSender());
        }
        _validateStrategyConfig(newConfig);

        bytes32 oldCommitment = _commitmentHash(oldConfig);
        bytes32 newCommitment = _commitmentHash(newConfig);
        if (activeCommitments[newCommitment]) revert DuplicateStrategy();

        if (newCommitment != oldCommitment) {
            activeCommitments[oldCommitment] = false;
            activeCommitments[newCommitment] = true;
            strategyCommitments[strategyId] = newCommitment;
        }

        // Last sheduled time is already hour aligned
        state.nextTriggerAt = state.lastScheduledAt + newConfig.interval;

        emit StrategyEdited(strategyId, newConfig);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function pauseStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external onlyStrategyOwner(strategyId, config) {
        StrategyState storage state = _strategyStates[strategyId];
        if (state.status != Status.ACTIVE) {
            revert StrategyNotActive(strategyId);
        }

        state.status = Status.PAUSED;

        emit StrategyPaused(strategyId, state.nextTriggerAt);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function resumeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external onlyStrategyOwner(strategyId, config) {
        StrategyState storage state = _strategyStates[strategyId];
        if (state.status != Status.PAUSED) {
            revert StrategyNotActive(strategyId);
        }

        state.status = Status.ACTIVE;
        // @audit Should this be hour aligned?
        state.nextTriggerAt = block.timestamp + config.interval;

        emit StrategyResumed(strategyId, state.nextTriggerAt);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function cancelStrategy(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external onlyStrategyOwner(strategyId, config) {
        StrategyState storage state = _strategyStates[strategyId];
        if (
            state.status == Status.CANCELLED || state.status == Status.COMPLETED
        ) {
            revert StrategyNotActive(strategyId);
        }

        state.status = Status.CANCELLED;

        emit StrategyCancelled(strategyId);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function executeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData
    ) external onlyKeeper nonReentrant {
        bytes32 storedCommitment = strategyCommitments[strategyId];
        if (_commitmentHash(config) != storedCommitment) {
            revert CommitmentMismatch(strategyId);
        }

        StrategyState storage state = _strategyStates[strategyId];
        if (state.status != Status.ACTIVE) {
            revert StrategyNotActive(strategyId);
        }

        if (config.maxTrades > 0 && state.tradesExecuted >= config.maxTrades) {
            // This should never happened though
            state.status = Status.COMPLETED;
            emit StrategyCompleted(strategyId, "max_trades");
            return;
        }
        if (config.endDate > 0 && block.timestamp >= config.endDate) {
            state.status = Status.COMPLETED;
            emit StrategyCompleted(strategyId, "end_date");
            return;
        }

        if (block.timestamp < state.nextTriggerAt) {
            revert ExecutionWindowNotReached(
                strategyId,
                state.nextTriggerAt,
                block.timestamp
            );
        }

        _executeStrategy(strategyId, config, ensoData, state);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function strategyStates(
        uint256 strategyId
    ) external view returns (StrategyState memory) {
        return _strategyStates[strategyId];
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function checkUpkeep(
        uint256 strategyId,
        StrategyConfig calldata config
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        performData = "";
        if (_commitmentHash(config) != strategyCommitments[strategyId]) {
            return (false, performData);
        }
        StrategyState storage state = _strategyStates[strategyId];

        if (state.status != Status.ACTIVE) {
            return (false, performData);
        }
        if (block.timestamp < state.nextTriggerAt) {
            return (false, performData);
        }
        if (config.maxTrades > 0 && state.tradesExecuted >= config.maxTrades) {
            return (false, performData);
        }
        if (config.endDate > 0 && block.timestamp >= config.endDate) {
            return (false, performData);
        }

        if (config.maxPrice > 0 || config.minPrice > 0) {
            ChainlinkOraclePrice memory inPrice = ChainlinkOracleUtils
                ._getPrice(config.inAssetFeed);
            ChainlinkOraclePrice memory outPrice = ChainlinkOracleUtils
                ._getPrice(config.outAssetFeed);
            uint256 executionPrice = ChainlinkOracleUtils.crossRate(
                inPrice,
                outPrice
            );
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

    /**
     * @dev Rounds `block.timestamp` up to the next whole hour boundary.
     */
    function _hourAlignedTimestamp() internal view returns (uint256) {
        return ((block.timestamp + 3599) / 3600) * 3600;
    }

    /**
     * @dev Returns the commitment hash for `config` — keccak256(abi.encode(config)).
     */
    function _commitmentHash(
        StrategyConfig calldata config
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(config));
    }

    /**
     * @dev Validates the fields of `config` that are independent of vault registry
     *      checks (those are enforced by the `onlyActiveFleetCommander` modifier).
     *      Reverts with `InvalidOwner`, `SameAsset`, `IntervalTooShort`,
     *      `InvalidSlippage`, `ZeroTradeAmount`, or `InvalidFeedAddress` on the
     *      first failing field.
     */
    function _validateStrategyConfig(
        StrategyConfig calldata config
    ) internal pure {
        if (config.owner == address(0)) revert InvalidOwner();
        if (address(config.sourceVault) == address(config.targetVault))
            revert SameAsset(address(config.sourceVault));
        if (config.inAsset == config.outAsset)
            revert SameAsset(address(config.inAsset));
        if (config.interval < _MIN_INTERVAL) {
            revert IntervalTooShort(config.interval, _MIN_INTERVAL);
        }
        if (BPS.wrap(config.slippageBps) > _MAX_SLIPPAGE_BPS) {
            revert InvalidSlippage(config.slippageBps);
        }
        if (config.tradeAmount == 0) {
            revert ZeroTradeAmount();
        }
        if (
            config.inAssetFeed == address(0) ||
            config.outAssetFeed == address(0)
        ) {
            revert InvalidFeedAddress();
        }
    }

    /**
     * @dev Fetches oracle prices, enforces price-guard bounds, pulls funds from
     *      the owner via Permit2, then delegates to `_executeSwap`.
     *      Reverts with `PriceAboveCeiling` or `PriceBelowFloor` when the
     *      current execution price falls outside the strategy's configured bounds.
     */
    function _executeStrategy(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state
    ) internal {
        // Convert source shares → inAssets, then derive expectedOutAssets and
        // oracle prices in one call. Prices are returned for reuse in the guard.
        // This spends more gas for a failing call but makes the architecture more
        // readable
        uint256 inAssets = config.sourceVault.convertToAssets(
            config.tradeAmount
        );
        (
            uint256 expectedOutAssets,
            ChainlinkOraclePrice memory inPrice,
            ChainlinkOraclePrice memory outPrice
        ) = ChainlinkOracleUtils.convertAmount(
                inAssets,
                config.inAsset,
                config.inAssetFeed,
                config.outAsset,
                config.outAssetFeed
            );

        uint256 executionPrice = ChainlinkOracleUtils.crossRate(
            inPrice,
            outPrice
        );
        if (config.maxPrice > 0 && executionPrice > config.maxPrice) {
            revert PriceAboveCeiling(executionPrice, config.maxPrice);
        }
        if (config.minPrice > 0 && executionPrice < config.minPrice) {
            revert PriceBelowFloor(executionPrice, config.minPrice);
        }

        uint256 expectedOutShares = config.targetVault.previewDeposit(
            expectedOutAssets
        );
        uint256 minOut = expectedOutShares.subtractBps(
            BPS.wrap(config.slippageBps)
        );

        _pullFunds(
            config.owner,
            address(config.sourceVault),
            config.tradeAmount
        );

        _executeSwap(strategyId, config, ensoData, state, minOut);
    }

    /**
     * @dev Performs the CEI sequence for a single DCA trade:
     *      1. Effects — advance `tradesExecuted`, `lastScheduledAt`, `nextTriggerAt`.
     *      2. Interactions — route source shares through Enso, verify `minOut`,
     *         transfer target shares to the owner.
     *      3. Emit `ExecutionCompleted` and, if terminal, `StrategyCompleted`.
     *      Reverts with `SwapOutputBelowMinOut` when the received target shares
     *      fall below the slippage-adjusted minimum.
     */
    function _executeSwap(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state,
        uint256 minOut
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

        if (config.maxTrades > 0 && tradesExecuted >= config.maxTrades) {
            state.status = Status.COMPLETED;
            emit StrategyCompleted(strategyId, "max_trades");
        } else if (config.endDate > 0 && nextTriggerAt >= config.endDate) {
            state.status = Status.COMPLETED;
            emit StrategyCompleted(strategyId, "end_date");
        }
    }
}
