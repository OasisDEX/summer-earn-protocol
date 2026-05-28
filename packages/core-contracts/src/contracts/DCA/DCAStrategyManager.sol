// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IAllowanceTransfer, ISignatureTransfer} from "../../interfaces/permit2/IPermit2.sol";
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

    /// @notice Maximum allowed interval between executions (90 days ≈ 3 months).
    uint256 private constant _MAX_INTERVAL = 90 days;

    /// @notice Maximum allowed slippage in BPS (50%).
    BPS private constant _MAX_SLIPPAGE_BPS = BPS.wrap(5000);

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
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
    {}

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
        strategyId = _createStrategy(config);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function depositAndCreate(
        StrategyConfig calldata config,
        uint256 assetAmount
    )
        external
        ownerOnlySender(config)
        onlyActiveFleetCommander(config.sourceVault, "source")
        onlyActiveFleetCommander(config.targetVault, "target")
        returns (uint256 strategyId)
    {
        if (assetAmount == 0) revert ZeroDeposit();

        strategyId = _createStrategy(config);

        IERC20 inAsset = IERC20(address(config.inAsset));
        inAsset.safeTransferFrom(_msgSender(), address(this), assetAmount);
        _depositPulledAsset(
            config.sourceVault,
            inAsset,
            _msgSender(),
            assetAmount
        );
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function createStrategyWithPermit2(
        StrategyConfig calldata config,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    )
        external
        ownerOnlySender(config)
        onlyActiveFleetCommander(config.sourceVault, "source")
        onlyActiveFleetCommander(config.targetVault, "target")
        returns (uint256 strategyId)
    {
        address expectedToken = address(config.sourceVault);
        if (permitSingle.details.token != expectedToken) {
            revert InvalidPermit2Token(
                expectedToken,
                permitSingle.details.token
            );
        }

        strategyId = _createStrategy(config);

        _applyPermit2Allowance(_msgSender(), permitSingle, signature);
    }

    /**
     * @inheritdoc IDCAStrategyManager
     */
    function depositAndCreateWithPermit2(
        StrategyConfig calldata config,
        uint256 assetAmount,
        Permit2DepositBundle calldata permits
    )
        external
        ownerOnlySender(config)
        onlyActiveFleetCommander(config.sourceVault, "source")
        onlyActiveFleetCommander(config.targetVault, "target")
        returns (uint256 strategyId)
    {
        if (assetAmount == 0) revert ZeroDeposit();
        if (permits.shares.details.token != address(config.sourceVault)) {
            revert InvalidPermit2Token(
                address(config.sourceVault),
                permits.shares.details.token
            );
        }

        strategyId = _createStrategy(config);

        // Set the recurring sub-allowance for keeper-driven pulls.
        _applyPermit2Allowance(_msgSender(), permits.shares, permits.sharesSig);

        // Pull the one-shot `inAsset` deposit via SignatureTransfer and deposit
        // it into `sourceVault` with shares routed to the user.
        _pullFundsWithPermit2(
            _msgSender(),
            address(config.inAsset),
            assetAmount,
            permits.inAsset,
            permits.inAssetSig
        );
        _depositPulledAsset(
            config.sourceVault,
            IERC20(address(config.inAsset)),
            _msgSender(),
            assetAmount
        );
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

        _requireNonTerminal(strategyId, state.status);

        // Ownership transfer via edit would silently re-key the commitment proof.
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
        _requireNonTerminal(strategyId, state.status);

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
    )
        external
        onlyKeeper
        nonReentrant
        onlyActiveFleetCommander(config.sourceVault, "source")
        onlyActiveFleetCommander(config.targetVault, "target")
    {
        bytes32 storedCommitment = strategyCommitments[strategyId];
        if (_commitmentHash(config) != storedCommitment) {
            revert CommitmentMismatch(strategyId);
        }

        StrategyState storage state = _strategyStates[strategyId];
        if (state.status != Status.ACTIVE) {
            revert StrategyNotActive(strategyId);
        }

        if (state.tradesExecuted >= config.maxTrades) {
            _markCompleted(strategyId, state, "max_trades");
            return;
        }
        if (config.endDate > 0 && block.timestamp >= config.endDate) {
            _markCompleted(strategyId, state, "end_date");
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
        if (state.tradesExecuted >= config.maxTrades) {
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
     * @dev Approves `sourceVault` for `assetAmount` of `inAsset` already held
     *      by this contract, deposits with `shareReceiver` as the recipient,
     *      and resets the allowance to 0 for hygiene. Caller is responsible
     *      for pulling the assets into this contract beforehand.
     */
    function _depositPulledAsset(
        IFleetCommander sourceVault,
        IERC20 inAsset,
        address shareReceiver,
        uint256 assetAmount
    ) internal {
        inAsset.forceApprove(address(sourceVault), assetAmount);
        sourceVault.deposit(assetAmount, shareReceiver);
        inAsset.forceApprove(address(sourceVault), 0);
    }

    /**
     * @dev Reverts with `StrategyNotActive` if `status` is one of the terminal
     *      states (CANCELLED, COMPLETED). Shared by `editStrategy` and
     *      `cancelStrategy`.
     */
    function _requireNonTerminal(
        uint256 strategyId,
        Status status
    ) internal pure {
        if (status == Status.CANCELLED || status == Status.COMPLETED) {
            revert StrategyNotActive(strategyId);
        }
    }

    /**
     * @dev Flips a strategy to `COMPLETED` and emits `StrategyCompleted`.
     *      Centralises the state-write + event-emit pair used by all
     *      terminal-transition sites (pre-flight in `executeStrategy` and
     *      post-trade in `_executeSwap`).
     */
    function _markCompleted(
        uint256 strategyId,
        StrategyState storage state,
        bytes32 reason
    ) internal {
        state.status = Status.COMPLETED;
        emit StrategyCompleted(strategyId, reason);
    }

    /**
     * @dev Shared body for `createStrategy` and `depositAndCreate`. Assumes the
     *      caller-side modifier stack (`ownerOnlySender`, `onlyActiveFleetCommander` x2)
     *      has already run; performs field validation, duplicate-commitment guard,
     *      ID allocation, state initialization, and emission.
     */
    function _createStrategy(
        StrategyConfig calldata config
    ) internal returns (uint256 strategyId) {
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
     *      `IntervalTooLong`, `InvalidSlippage`, `ZeroTradeAmount`, `ZeroMaxTrades`,
     *      or `InvalidFeedAddress` on the first failing field.
     */
    function _validateStrategyConfig(
        StrategyConfig calldata config
    ) internal view {
        if (config.owner == address(0)) revert InvalidOwner();
        if (address(config.sourceVault) == address(config.targetVault))
            revert SameAsset(address(config.sourceVault));
        if (config.inAsset == config.outAsset)
            revert SameAsset(address(config.inAsset));
        address expectedIn = config.sourceVault.asset();
        if (address(config.inAsset) != expectedIn) {
            revert InAssetVaultMismatch(expectedIn, address(config.inAsset));
        }
        address expectedOut = config.targetVault.asset();
        if (address(config.outAsset) != expectedOut) {
            revert OutAssetVaultMismatch(expectedOut, address(config.outAsset));
        }
        if (config.interval < _MIN_INTERVAL) {
            revert IntervalTooShort(config.interval, _MIN_INTERVAL);
        }
        if (config.interval > _MAX_INTERVAL) {
            revert IntervalTooLong(config.interval, _MAX_INTERVAL);
        }
        if (BPS.wrap(config.slippageBps) > _MAX_SLIPPAGE_BPS) {
            revert InvalidSlippage(config.slippageBps);
        }
        if (config.tradeAmount == 0) {
            revert ZeroTradeAmount();
        }
        if (config.maxTrades == 0) {
            revert ZeroMaxTrades();
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
        uint256 inAssets = config.sourceVault.convertToAssets(
            config.tradeAmount
        );

        // Scoped to free stack slots before destructuring `_executeSwap`'s returns.
        uint256 minOut;
        {
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
            if (expectedOutShares == 0) revert ZeroExpectedOutShares();
            minOut = expectedOutShares.subtractBps(
                BPS.wrap(config.slippageBps)
            );
        }

        uint256 sourceSharesBaseline = IERC20(address(config.sourceVault))
            .balanceOf(address(this));

        _pullFunds(
            config.owner,
            address(config.sourceVault),
            config.tradeAmount
        );

        (
            uint256 swappedAmount,
            uint256 outAssets,
            uint256 nextTriggerAt,
            uint248 tradesExecuted
        ) = _executeSwap(
                strategyId,
                config,
                ensoData,
                state,
                minOut,
                sourceSharesBaseline
            );

        emit ExecutionCompleted(
            strategyId,
            tradesExecuted,
            config.tradeAmount,
            swappedAmount,
            inAssets,
            outAssets,
            nextTriggerAt
        );

        if (tradesExecuted >= config.maxTrades) {
            _markCompleted(strategyId, state, "max_trades");
        } else if (config.endDate > 0 && nextTriggerAt >= config.endDate) {
            _markCompleted(strategyId, state, "end_date");
        }
    }

    /**
     * @dev CEI sequence for the swap mechanics of a single DCA trade: advance
     *      state, route source shares through Enso, verify `minOut`, transfer
     *      target shares to the owner, refund any unused source shares. Lifecycle
     *      decisions (terminal-state transition, event emission) are handled by
     *      the caller. Reverts with `SwapOutputBelowMinOut` when received shares
     *      are below the slippage-adjusted minimum.
     *
     *      `sourceSharesBaseline` is the manager's source-vault share balance
     *      captured by the caller before pulling funds. Any source shares left
     *      in the contract above this baseline after the Enso call are returned
     *      to `config.owner` — defending the "no funds held between txs"
     *      invariant against routers that underspend the approval.
     */
    function _executeSwap(
        uint256 strategyId,
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state,
        uint256 minOut,
        uint256 sourceSharesBaseline
    )
        internal
        returns (
            uint256 swappedAmount,
            uint256 outAssets,
            uint256 nextTriggerAt,
            uint248 tradesExecuted
        )
    {
        // Effects.
        nextTriggerAt = block.timestamp + config.interval;
        state.tradesExecuted += 1;
        state.lastScheduledAt = block.timestamp;
        state.nextTriggerAt = nextTriggerAt;
        tradesExecuted = state.tradesExecuted;

        IERC20 targetShares = IERC20(address(config.targetVault));
        IERC20 sourceShares = IERC20(address(config.sourceVault));
        uint256 targetSharesBefore = targetShares.balanceOf(address(this));

        // Interactions.
        _ensoSwap(address(config.sourceVault), config.tradeAmount, ensoData);

        swappedAmount =
            targetShares.balanceOf(address(this)) -
            targetSharesBefore;

        if (swappedAmount < minOut) {
            revert SwapOutputBelowMinOut(strategyId, minOut, swappedAmount);
        }

        targetShares.safeTransfer(config.owner, swappedAmount);

        // Refund any source-vault shares the router didn't consume.
        uint256 sourceSharesAfter = sourceShares.balanceOf(address(this));
        if (sourceSharesAfter > sourceSharesBaseline) {
            sourceShares.safeTransfer(
                config.owner,
                sourceSharesAfter - sourceSharesBaseline
            );
        }

        outAssets = config.targetVault.convertToAssets(swappedAmount);
    }
}
