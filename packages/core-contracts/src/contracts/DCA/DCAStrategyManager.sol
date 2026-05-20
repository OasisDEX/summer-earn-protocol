// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ISignatureTransfer} from "../../interfaces/permit2/IPermit2.sol";

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
    uint256 private constant _CHAINLINK_DECIMALS = 8;

    uint256 private _nextStrategyId;
    mapping(uint256 => bytes32) private _strategyCommitments;
    mapping(uint256 => StrategyState) private _strategyStates;
    mapping(uint256 => address) private _strategyOwners;

    address public immutable ENSO_ROUTER;
    IHarborCommand public immutable HARBOR_COMMAND;
    AggregatorV3Interface public immutable ETH_USD_FEED;
    AggregatorV3Interface public immutable USDC_USD_FEED;
    ISignatureTransfer public immutable PERMIT2;

    constructor(
        address _accessManager,
        address _ensoRouter,
        address _harborCommand,
        address _ethUsdFeed,
        address _usdcUsdFeed,
        address _permit2
    ) ProtocolAccessManaged(_accessManager) {
        if (_ensoRouter == address(0)) revert InvalidRouterAddress();
        if (_harborCommand == address(0)) revert InvalidHarborCommandAddress();

        ENSO_ROUTER = _ensoRouter;
        HARBOR_COMMAND = IHarborCommand(_harborCommand);
        ETH_USD_FEED = AggregatorV3Interface(_ethUsdFeed);
        USDC_USD_FEED = AggregatorV3Interface(_usdcUsdFeed);
        PERMIT2 = ISignatureTransfer(_permit2);
    }

    function createStrategy(
        StrategyConfig calldata config,
        bytes calldata permit2Data
    ) external returns (uint256 strategyId) {
        if (config.interval == 0) revert InvalidInterval(0);
        if (config.slippageBps > _BPS)
            revert InvalidSlippage(config.slippageBps);
        if (config.tradeAmount == 0) revert ZeroTradeAmount();
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

        bytes32 commitment = keccak256(abi.encode(mutableConfig));
        _strategyCommitments[strategyId] = commitment;
        _strategyOwners[strategyId] = config.owner;

        uint256 firstTriggerAt = block.timestamp + config.interval;
        _strategyStates[strategyId] = StrategyState({
            status: uint8(Status.ACTIVE),
            tradesExecuted: 0,
            interval: config.interval,
            nextTriggerAt: firstTriggerAt,
            lastScheduledAt: block.timestamp
        });

        if (permit2Data.length > 0) {
            _setupPermit2(
                config.owner,
                address(config.sourceVault),
                permit2Data
            );
        }

        emit StrategyCreated(
            strategyId,
            config.owner,
            commitment,
            firstTriggerAt
        );
    }

    function editStrategy(StrategyConfig calldata config) external {
        if (msg.sender != _strategyOwners[config.strategyId]) {
            revert UnauthorizedAccess(config.strategyId, msg.sender);
        }

        bytes32 oldCommitment = _strategyCommitments[config.strategyId];
        bytes32 newCommitment = keccak256(abi.encode(config));
        if (oldCommitment != newCommitment) {
            _strategyCommitments[config.strategyId] = newCommitment;
        }

        StrategyState storage state = _strategyStates[config.strategyId];
        state.interval = config.interval;
        state.nextTriggerAt = state.lastScheduledAt + state.interval;

        emit StrategyEdited(
            config.strategyId,
            oldCommitment,
            newCommitment,
            state.nextTriggerAt
        );
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

        _executeSwap(config, ensoData, state);
    }

    function _executeSwap(
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state
    ) internal {
        uint256 strategyId = config.strategyId;
        (uint256 inPrice, uint256 outPrice) = _getOraclePrices(
            config.sourceVault,
            config.targetVault
        );

        if (inPrice == 0 || outPrice == 0) {
            _skipWithAdvance(state, strategyId, "oracle_price_zero", "");
            return;
        }

        if (config.maxPrice > 0 && inPrice > config.maxPrice) {
            _skipWithAdvance(
                state,
                strategyId,
                "price_ceiling",
                abi.encode(inPrice, config.maxPrice)
            );
            return;
        }

        if (config.minPrice > 0 && inPrice < config.minPrice) {
            _skipWithAdvance(
                state,
                strategyId,
                "price_floor",
                abi.encode(inPrice, config.minPrice)
            );
            return;
        }

        uint256 tradeAmount = config.tradeAmount;
        uint256 pulled = _pullFunds(
            config.owner,
            address(config.sourceVault),
            tradeAmount
        );

        if (pulled < tradeAmount) {
            _skipWithAdvance(
                state,
                strategyId,
                "insufficient_funds",
                abi.encode(pulled, tradeAmount)
            );
            return;
        }

        _executeSwapCore(
            config,
            ensoData,
            state,
            strategyId,
            tradeAmount,
            inPrice,
            outPrice
        );
    }

    function _executeSwapCore(
        StrategyConfig calldata config,
        bytes calldata ensoData,
        StrategyState storage state,
        uint256 strategyId,
        uint256 tradeAmount,
        uint256 inPrice,
        uint256 outPrice
    ) internal {
        uint256 slippageBps = config.slippageBps;
        uint256 interval = config.interval;
        address targetVault = address(config.targetVault);
        address owner = config.owner;

        uint256 targetSharesBefore = IERC20(targetVault).balanceOf(
            address(this)
        );

        IERC20(address(config.sourceVault)).forceApprove(
            ENSO_ROUTER,
            tradeAmount
        );

        (bool success, ) = ENSO_ROUTER.call(ensoData);
        if (!success) revert SwapFailed(strategyId);

        uint256 targetSharesAfter = IERC20(targetVault).balanceOf(
            address(this)
        );
        uint256 swappedAmount = targetSharesAfter - targetSharesBefore;

        uint256 minOut = _calculateMinOut(
            tradeAmount,
            inPrice,
            outPrice,
            slippageBps
        );

        if (swappedAmount < minOut) {
            revert SwapOutputBelowMinOut(strategyId, minOut, swappedAmount);
        }

        IERC20(targetVault).safeTransfer(owner, swappedAmount);

        _updateStateAfterSwap(
            state,
            strategyId,
            tradeAmount,
            swappedAmount,
            interval
        );
    }

    function _updateStateAfterSwap(
        StrategyState storage state,
        uint256 strategyId,
        uint256 tradeAmount,
        uint256 swappedAmount,
        uint256 interval
    ) internal {
        uint256 lastScheduled = state.nextTriggerAt;
        uint256 nextTriggerAt = lastScheduled + interval;

        state.tradesExecuted += 1;
        state.lastScheduledAt = lastScheduled;
        state.nextTriggerAt = nextTriggerAt;

        emit ExecutionCompleted(
            strategyId,
            state.tradesExecuted,
            tradeAmount,
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
        state.nextTriggerAt = state.lastScheduledAt + state.interval;
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
    ) external view returns (bool, bytes memory) {
        return (false, "");
    }

    function _pullFunds(
        address owner,
        address sourceVault,
        uint256 amount
    ) internal returns (uint256) {
        IERC20(sourceVault).safeTransferFrom(owner, address(this), amount);
        return amount;
    }

    function _setupPermit2(
        address owner,
        address token,
        bytes calldata permit2Data
    ) internal {
        (uint256 nonce, uint256 deadline, bytes memory signature) = abi.decode(
            permit2Data,
            (uint256, uint256, bytes)
        );

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: IERC20(token),
                    amount: type(uint256).max
                }),
                nonce: nonce,
                deadline: deadline
            });

        ISignatureTransfer.SignatureTransferDetails
            memory transferDetails = ISignatureTransfer
                .SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: type(uint256).max
                });

        PERMIT2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

    function _getOraclePrices(
        IFleetCommander sourceVault,
        IFleetCommander targetVault
    ) internal view returns (uint256 inPrice, uint256 outPrice) {
        (, int256 ethUsdRaw, , , ) = ETH_USD_FEED.latestRoundData();
        if (ethUsdRaw <= 0) revert OraclePriceZero();
        uint256 ethUsd = uint256(ethUsdRaw);

        (, int256 usdcUsdRaw, , , ) = USDC_USD_FEED.latestRoundData();
        if (usdcUsdRaw <= 0) revert OraclePriceZero();
        uint256 usdcUsd = uint256(usdcUsdRaw);

        address sourceAsset = address(sourceVault.asset());
        address targetAsset = address(targetVault.asset());

        bool sourceIsEth = sourceAsset ==
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        bool sourceIsUsdc = sourceAsset ==
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        bool targetIsEth = targetAsset ==
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        bool targetIsUsdc = targetAsset ==
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        if (sourceIsEth && targetIsUsdc) {
            inPrice = ethUsd;
            outPrice = usdcUsd;
        } else if (sourceIsUsdc && targetIsEth) {
            inPrice = usdcUsd;
            outPrice = ethUsd;
        } else if (sourceIsEth && !targetIsEth) {
            inPrice = ethUsd;
            outPrice = (ethUsd * (10 ** _CHAINLINK_DECIMALS)) / usdcUsd;
        } else if (!sourceIsEth && targetIsEth) {
            inPrice = (usdcUsd * (10 ** _CHAINLINK_DECIMALS)) / ethUsd;
            outPrice = ethUsd;
        } else if (sourceIsUsdc && !targetIsUsdc) {
            inPrice = usdcUsd;
            outPrice = (usdcUsd * (10 ** _CHAINLINK_DECIMALS)) / ethUsd;
        } else if (!sourceIsUsdc && targetIsUsdc) {
            inPrice = (usdcUsd * (10 ** _CHAINLINK_DECIMALS)) / ethUsd;
            outPrice = usdcUsd;
        } else {
            inPrice = (ethUsd * (10 ** _CHAINLINK_DECIMALS)) / usdcUsd;
            outPrice = (ethUsd * (10 ** _CHAINLINK_DECIMALS)) / usdcUsd;
        }
    }

    function _calculateMinOut(
        uint256 inAmount,
        uint256 inPrice,
        uint256 outPrice,
        uint256 slippageBps
    ) internal pure returns (uint256) {
        uint256 expectedOut = (inAmount * inPrice) / outPrice;

        return (expectedOut * (_BPS - slippageBps)) / _BPS;
    }

    error InvalidRouterAddress();
    error InvalidHarborCommandAddress();
    error InvalidSourceVault(address vault);
    error InvalidTargetVault(address vault);
    error SwapFailed(uint256 strategyId);
}
