// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

import {IDCAStrategyManager} from "../../../interfaces/arks/IDCAStrategyManager.sol";
import {IDCAStrategyManagerErrors} from "../../../errors/arks/IDCAStrategyManagerErrors.sol";
import {IDCAStrategyManagerEvents} from "../../../events/arks/IDCAStrategyManagerEvents.sol";
import {IAggregationRouterV6} from "../../../interfaces/1inch/IAggregationRouterV6.sol";
import {IFleetCommander} from "../../../interfaces/IFleetCommander.sol";
import {IHarborCommand} from "../../../interfaces/IHarborCommand.sol";
import {AggregatorV3Interface} from "../../../interfaces/external/Chainlink/AggregatorV3Interface.sol";

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

    IAggregationRouterV6 public immutable ONE_INCH_ROUTER;
    IHarborCommand public immutable HARBOR_COMMAND;
    AggregatorV3Interface public immutable ETH_USD_FEED;
    AggregatorV3Interface public immutable USDC_USD_FEED;

    constructor(
        address _accessManager,
        address _oneInchRouter,
        address _harborCommand,
        address _ethUsdFeed,
        address _usdcUsdFeed
    ) ProtocolAccessManaged(_accessManager) {
        if (_oneInchRouter == address(0)) revert InvalidRouterAddress();
        if (_harborCommand == address(0)) revert InvalidHarborCommandAddress();

        ONE_INCH_ROUTER = IAggregationRouterV6(_oneInchRouter);
        HARBOR_COMMAND = IHarborCommand(_harborCommand);
        ETH_USD_FEED = AggregatorV3Interface(_ethUsdFeed);
        USDC_USD_FEED = AggregatorV3Interface(_usdcUsdFeed);
    }

    function createStrategy(
        StrategyConfig calldata config,
        bytes calldata
    ) external returns (uint256 strategyId) {
        if (config.interval == 0) revert InvalidInterval(0);
        if (config.slippageBps > _BPS) revert InvalidSlippage(config.slippageBps);
        if (config.tradeAmount == 0) revert ZeroTradeAmount();
        if (address(config.inAsset) == address(config.outAsset)) {
            revert SameAsset(address(config.inAsset));
        }
        if (!HARBOR_COMMAND.activeFleetCommanders(address(config.sourceVault))) {
            revert InvalidSourceVault(address(config.sourceVault));
        }
        if (!HARBOR_COMMAND.activeFleetCommanders(address(config.targetVault))) {
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

        emit StrategyCreated(strategyId, config.owner, commitment, firstTriggerAt);
    }

    function editStrategy(StrategyConfig calldata config) external {
        if (msg.sender != config.owner) {
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
        bytes calldata oneInchData
    ) external onlyKeeper nonReentrant {
        bytes32 storedCommitment = _strategyCommitments[config.strategyId];
        if (keccak256(abi.encode(config)) != storedCommitment) {
            revert CommitmentMismatch(config.strategyId);
        }

        StrategyState storage state = _strategyStates[config.strategyId];
        if (state.status != uint8(Status.ACTIVE)) {
            revert StrategyNotActive(config.strategyId);
        }
        if (block.timestamp < state.nextTriggerAt) {
            revert ExecutionWindowNotReached(
                config.strategyId,
                state.nextTriggerAt,
                block.timestamp
            );
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

        (uint256 inPrice, uint256 outPrice) = _getOraclePrices(
            config.inAsset,
            config.outAsset
        );

        if (inPrice == 0) revert OraclePriceZero();
        if (outPrice == 0) revert OraclePriceZero();

        if (config.maxPrice > 0 && inPrice > config.maxPrice) {
            state.nextTriggerAt = state.lastScheduledAt + state.interval;
            emit ExecutionSkipped(
                config.strategyId,
                "price_ceiling",
                abi.encode(inPrice, config.maxPrice)
            );
            return;
        }
        if (config.minPrice > 0 && inPrice < config.minPrice) {
            state.nextTriggerAt = state.lastScheduledAt + state.interval;
            emit ExecutionSkipped(
                config.strategyId,
                "price_floor",
                abi.encode(inPrice, config.minPrice)
            );
            return;
        }

        _pullFunds(config);

        uint256 sharesBalance = IERC20(address(config.sourceVault)).balanceOf(
            address(this)
        );

        if (sharesBalance < config.tradeAmount) {
            state.nextTriggerAt = state.lastScheduledAt + state.interval;
            emit ExecutionSkipped(
                config.strategyId,
                "insufficient_funds",
                abi.encode(sharesBalance, config.tradeAmount)
            );
            return;
        }

        uint256 underlyingReceived = _redeemShares(config, sharesBalance);

        if (underlyingReceived == 0) {
            state.nextTriggerAt = state.lastScheduledAt + state.interval;
            emit ExecutionSkipped(
                config.strategyId,
                "redeem_failed",
                ""
            );
            return;
        }

        uint256 minOut = _calculateMinOut(
            underlyingReceived,
            inPrice,
            outPrice,
            IERC20Metadata(address(config.inAsset)).decimals(),
            IERC20Metadata(address(config.outAsset)).decimals(),
            config.slippageBps
        );

        uint256 outReceived = _swap(
            config.inAsset,
            config.outAsset,
            underlyingReceived,
            minOut,
            oneInchData
        );

        if (outReceived < minOut) {
            revert SwapOutputBelowMinOut(config.strategyId, minOut, outReceived);
        }

        _depositToTargetVault(config, outReceived);

        state.tradesExecuted += 1;
        state.lastScheduledAt = state.nextTriggerAt;
        state.nextTriggerAt = state.lastScheduledAt + state.interval;

        emit ExecutionCompleted(
            config.strategyId,
            state.tradesExecuted,
            underlyingReceived,
            outReceived,
            state.nextTriggerAt
        );
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

    function _pullFunds(StrategyConfig calldata config) internal {
        IERC20 sourceShares = IERC20(address(config.sourceVault));
        uint256 allowance = sourceShares.allowance(
            config.owner,
            address(this)
        );

        if (allowance >= config.tradeAmount) {
            sourceShares.safeTransferFrom(
                config.owner,
                address(this),
                config.tradeAmount
            );
        } else {
            sourceShares.safeTransferFrom(
                config.owner,
                address(this),
                config.tradeAmount
            );
        }
    }

    function _redeemShares(
        StrategyConfig calldata config,
        uint256 sharesBalance
    ) internal returns (uint256) {
        IERC20 sourceShares = IERC20(address(config.sourceVault));
        sourceShares.forceApprove(address(config.sourceVault), sharesBalance);

        uint256 balanceBefore = config.inAsset.balanceOf(address(this));
        config.sourceVault.redeem(sharesBalance, address(this), address(this));
        uint256 balanceAfter = config.inAsset.balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }

    function _swap(
        IERC20 inToken,
        IERC20 outToken,
        uint256 inAmount,
        uint256 minOut,
        bytes calldata swapData
    ) internal returns (uint256) {
        uint256 balanceBefore = outToken.balanceOf(address(this));

        inToken.forceApprove(address(ONE_INCH_ROUTER), inAmount);

        (bool success, ) = address(ONE_INCH_ROUTER).call(swapData);
        if (!success) revert SwapFailed();

        uint256 balanceAfter = outToken.balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    function _depositToTargetVault(
        StrategyConfig calldata config,
        uint256 assets
    ) internal {
        IERC20 outAsset = config.outAsset;
        outAsset.forceApprove(address(config.targetVault), assets);

        config.targetVault.deposit(assets, config.owner);
    }

    function _getOraclePrices(
        IERC20 inAsset,
        IERC20 outAsset
    ) internal view returns (uint256 inPrice, uint256 outPrice) {
        (, int256 ethUsdRaw, , , ) = ETH_USD_FEED.latestRoundData();
        if (ethUsdRaw <= 0) revert OraclePriceZero();
        uint256 ethUsd = uint256(ethUsdRaw);

        (, int256 usdcUsdRaw, , , ) = USDC_USD_FEED.latestRoundData();
        if (usdcUsdRaw <= 0) revert OraclePriceZero();
        uint256 usdcUsd = uint256(usdcUsdRaw);

        address inAssetAddr = address(inAsset);
        address outAssetAddr = address(outAsset);

        bool inIsEth = inAssetAddr == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        bool inIsUsdc = inAssetAddr == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        bool outIsEth = outAssetAddr == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        bool outIsUsdc = outAssetAddr == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        if (inIsEth && outIsUsdc) {
            inPrice = ethUsd;
            outPrice = usdcUsd;
        } else if (inIsUsdc && outIsEth) {
            inPrice = usdcUsd;
            outPrice = ethUsd;
        } else if (inIsEth && !outIsEth) {
            inPrice = ethUsd;
            outPrice = (ethUsd * 10 ** _CHAINLINK_DECIMALS) / usdcUsd;
        } else if (!inIsEth && outIsEth) {
            inPrice = (usdcUsd * 10 ** _CHAINLINK_DECIMALS) / ethUsd;
            outPrice = ethUsd;
        } else if (inIsUsdc && !outIsUsdc) {
            inPrice = usdcUsd;
            outPrice = (usdcUsd * 10 ** _CHAINLINK_DECIMALS) / ethUsd;
        } else if (!inIsUsdc && outIsUsdc) {
            inPrice = (usdcUsd * 10 ** _CHAINLINK_DECIMALS) / ethUsd;
            outPrice = usdcUsd;
        } else {
            inPrice = (ethUsd * 10 ** _CHAINLINK_DECIMALS) / usdcUsd;
            outPrice = (ethUsd * 10 ** _CHAINLINK_DECIMALS) / usdcUsd;
        }
    }

    function _calculateMinOut(
        uint256 inAmount,
        uint256 inPrice,
        uint256 outPrice,
        uint8 inDecimals,
        uint8 outDecimals,
        uint256 slippageBps
    ) internal pure returns (uint256) {
        uint256 expectedOut = (inAmount * inPrice * 10 ** outDecimals) / (outPrice * 10 ** inDecimals);

        return expectedOut * (_BPS - slippageBps) / _BPS;
    }

    function _getConfigFromCommitment(
        uint256 strategyId,
        bytes32 commitment
    ) internal pure returns (StrategyConfig memory config) {
        config.strategyId = strategyId;
    }

    error InvalidRouterAddress();
    error InvalidHarborCommandAddress();
    error InvalidSourceVault(address vault);
    error InvalidTargetVault(address vault);
    error SwapFailed();
}