// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IStandardizedYield} from "@pendle/core-v2/contracts/interfaces/IStandardizedYield.sol";
import {IPPrincipalToken} from "@pendle/core-v2/contracts/interfaces/IPPrincipalToken.sol";
import {IPYieldToken} from "@pendle/core-v2/contracts/interfaces/IPYieldToken.sol";
import {PendlePYLpOracle} from "@pendle/core-v2/contracts/oracles/PendlePYLpOracle.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {ApproxParams} from "@pendle/core-v2/contracts/router/base/MarketApproxLib.sol";
import {LimitOrderData, TokenOutput, TokenInput} from "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import {SwapData} from "@pendle/core-v2/contracts/router/swap-aggregator/IPSwapAggregator.sol";
import {Percentage, PercentageUtils, PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {OracleNotReady, NoValidNextMarket, OracleDurationTooLow, SlippagePercentageTooHigh, InvalidAssetForSY} from "../../errors/arks/PendleArkErrors.sol";
import {IPendleArkEvents} from "../../events/arks/IPendleArkEvents.sol";

/**
 * @title PendleLPArk
 * @notice This contract manages a Pendle LP token strategy within the Ark system
 * @dev Inherits from Ark and implements Pendle-specific logic for LP positions
 */
contract PendleLPArk is Ark, IPendleArkEvents {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    // Constants
    Percentage private constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
    uint256 private constant MIN_ORACLE_DURATION = 15 minutes;

    // State variables
    address public market;
    address public router;
    address public immutable oracle;
    uint32 public oracleDuration;
    IStandardizedYield public SY;
    IPPrincipalToken public PT;
    IPYieldToken public YT;
    Percentage public slippagePercentage;
    uint256 public marketExpiry;
    ApproxParams public routerParams;
    LimitOrderData emptyLimitOrderData;
    SwapData public emptySwap;

    /**
     * @notice Constructor for PendleLPArk
     * @param _asset Address of the underlying asset
     * @param _market Address of the Pendle market
     * @param _oracle Address of the Pendle oracle
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _asset,
        address _market,
        address _oracle,
        address _router,
        ArkParams memory _params
    ) Ark(_params) {
        market = _market;
        router = _router;
        oracle = _oracle;
        oracleDuration = 30 minutes;
        slippagePercentage = PercentageUtils.fromFraction(5, 1000); // 0.5% default

        (SY, PT, YT) = IPMarketV3(_market).readTokens();
        if (
            !IStandardizedYield(SY).isValidTokenIn(_asset) ||
            !IStandardizedYield(SY).isValidTokenOut(_asset)
        ) {
            revert InvalidAssetForSY();
        }

        _setupRouterParams();
        _setupApprovals(_asset);
        _updateMarketData();
    }

    /**
     * @notice Internal function to set up router parameters
     */
    function _setupRouterParams() private {
        routerParams.guessMax = type(uint256).max;
        routerParams.maxIteration = 256;
        routerParams.eps = 1e15; // 0.1% precision
    }

    /**
     * @notice Internal function to set up token approvals
     * @param _asset Address of the underlying asset
     */
    function _setupApprovals(address _asset) private {
        IERC20(_asset).forceApprove(address(SY), type(uint256).max);
        IERC20(_asset).forceApprove(router, type(uint256).max);
        IERC20(market).forceApprove(router, type(uint256).max);
        IERC20(market).forceApprove(market, type(uint256).max);
    }

    /**
     * @notice Boards (deposits) assets into the Ark
     * @param amount Amount of assets to board
     */
    function _board(uint256 amount) internal override {
        _rolloverIfNeeded();
        _depositTokenForLp(amount);
    }

    /**
     * @notice Disembarks (withdraws) assets from the Ark
     * @param amount Amount of assets to disembark
     */
    function _disembark(uint256 amount) internal override {
        _rolloverIfNeeded();
        _redeemTokenFromLp(amount);
    }

    /**
     * @notice Deposits tokens for LP
     * @param _amount Amount of tokens to deposit
     */
    function _depositTokenForLp(uint256 _amount) internal {
        uint256 minLpOut = _assetToLP(_amount).subtractPercentage(
            slippagePercentage
        );

        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(config.token),
            netTokenIn: _amount,
            tokenMintSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });
        IPAllActionV3(router).addLiquiditySingleToken(
            address(this),
            market,
            minLpOut,
            routerParams,
            tokenInput,
            emptyLimitOrderData
        );
    }

    /**
     * @notice Redeems LP for tokens
     * @param amount Amount of underlying asset to redeem
     */
    function _redeemTokenFromLp(uint256 amount) internal {
        uint256 lpBalance = IERC20(market).balanceOf(address(this));
        uint256 withdrawAmountInLp = _assetToLP(amount).addPercentage(
            slippagePercentage
        );
        uint256 lpToRedeem = (withdrawAmountInLp > lpBalance)
            ? lpBalance
            : withdrawAmountInLp;

        uint256 expectedAssetOut = _LPtoAsset(lpToRedeem);
        uint256 minAssetOut = expectedAssetOut.subtractPercentage(
            slippagePercentage
        );

        IERC20(market).approve(router, type(uint256).max);
        TokenOutput memory tokenOutput = TokenOutput({
            tokenOut: address(config.token),
            minTokenOut: minAssetOut,
            tokenRedeemSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });
        IPAllActionV3(router).removeLiquiditySingleToken(
            address(this),
            market,
            lpToRedeem,
            tokenOutput,
            emptyLimitOrderData
        );
    }

    /**
     * @notice Returns the current rate (APY) for the LP position
     * @return The current APY
     */
    function rate() public pure override returns (uint256) {
        // TODO: rate will be deprcated in the future
        return type(uint256).max;
    }

    /**
     * @notice Returns the total assets held by the Ark
     * @return The total assets in underlying token
     * @dev we decrease the total assets by the allowed slippage so the redeemed amount is always higher than the requested amount
     */
    function totalAssets() public view override returns (uint256) {
        return
            _LPtoAsset(_balanceOfLP()).subtractPercentage(slippagePercentage);
    }

    /**
     * @notice Updates the market data (expiry)
     */
    function _updateMarketData() internal {
        marketExpiry = IPMarketV3(market).expiry();
    }

    /**
     * @notice Rolls over to a new market if the current one has expired
     */
    function _rolloverIfNeeded() internal {
        if (block.timestamp < marketExpiry) return;

        address newMarket = _findNextMarket();
        if (newMarket == address(0) || newMarket == market) {
            revert NoValidNextMarket();
        }

        _redeemAllToUnderlying();
        if (!_isOracleReady(newMarket)) {
            revert OracleNotReady();
        }

        _updateMarketAndTokens(newMarket);
        _updateMarketData();

        emit MarketRolledOver(newMarket);
    }

    /**
     * @notice Redeems all LP and SY to underlying tokens
     */
    function _redeemAllToUnderlying() internal {
        uint256 lpBalance = IERC20(market).balanceOf(address(this));
        uint256 expectedAssetOut = _LPtoAsset(lpBalance);
        uint256 minAssetOut = expectedAssetOut.subtractPercentage(
            slippagePercentage
        );

        if (lpBalance > 0) {
            TokenOutput memory tokenOutput = TokenOutput({
                tokenOut: address(config.token),
                minTokenOut: minAssetOut,
                tokenRedeemSy: address(config.token),
                pendleSwap: address(0),
                swapData: emptySwap
            });
            IPAllActionV3(router).removeLiquiditySingleToken(
                address(this),
                market,
                lpBalance,
                tokenOutput,
                emptyLimitOrderData
            );
        }
    }

    /**
     * @notice Updates market and token addresses, and sets up new approvals
     * @param newMarket Address of the new market
     */
    function _updateMarketAndTokens(address newMarket) internal {
        market = newMarket;
        (SY, PT, YT) = IPMarketV3(newMarket).readTokens();

        IERC20(config.token).forceApprove(address(SY), type(uint256).max);
        IERC20(SY).forceApprove(newMarket, type(uint256).max);
        IERC20(SY).forceApprove(router, type(uint256).max);
        IERC20(newMarket).forceApprove(router, type(uint256).max);
    }

    /**
     * @notice Finds the next valid market
     * @return Address of the next market
     */
    function _findNextMarket() internal pure returns (address) {
        // TODO: Implement logic to find the next valid market
        return 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
    }

    /**
     * @notice Converts LP amount to asset amount
     * @param _amount Amount of LP to convert
     * @return Equivalent amount of asset
     */
    function _LPtoAsset(uint256 _amount) internal view returns (uint256) {
        uint256 lpToAssetRate = PendlePYLpOracle(oracle).getLpToAssetRate(
            market,
            oracleDuration
        );
        return (_amount * lpToAssetRate) / WAD;
    }

    /**
     * @notice Converts asset amount to LP amount
     * @param _amount Amount of asset to convert
     * @return Equivalent amount of LP
     * @dev tehre is no reverse operation for `getLpToAssetRate`
     */
    function _assetToLP(uint256 _amount) internal view returns (uint256) {
        uint256 lpToAssetRate = PendlePYLpOracle(oracle).getLpToAssetRate(
            market,
            oracleDuration
        );
        return (_amount * WAD) / lpToAssetRate;
    }

    /**
     * @notice Returns the balance of LP held by the contract
     * @return Balance of LP
     */
    function _balanceOfLP() internal view returns (uint256) {
        return IERC20(market).balanceOf(address(this));
    }

    /**
     * @notice Sets the slippage tolerance in basis points
     * @param _slippagePercentage New slippage tolerance
     */
    function setSlippagePercentage(
        Percentage _slippagePercentage
    ) external onlyGovernor {
        if (_slippagePercentage > MAX_SLIPPAGE_PERCENTAGE) {
            revert SlippagePercentageTooHigh(
                _slippagePercentage,
                MAX_SLIPPAGE_PERCENTAGE
            );
        }
        slippagePercentage = _slippagePercentage;
        emit SlippageUpdated(_slippagePercentage);
    }

    /**
     * @notice Sets the oracle duration
     * @param _oracleDuration New oracle duration
     */
    function setOracleDuration(uint32 _oracleDuration) external onlyGovernor {
        if (_oracleDuration < MIN_ORACLE_DURATION) {
            revert OracleDurationTooLow(_oracleDuration, MIN_ORACLE_DURATION);
        }
        oracleDuration = _oracleDuration;
        emit OracleDurationUpdated(_oracleDuration);
    }

    /**
     * @notice Harvests rewards from the market
     * @return totalRewards amount of rewards harvested
     */
    function _harvest(
        address,
        bytes calldata
    ) internal override returns (uint256 totalRewards) {
        address[] memory rewardTokens = IPMarketV3(market).getRewardTokens();
        uint256[] memory rewardAmounts = IPMarketV3(market).redeemRewards(
            address(this)
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).safeTransfer(
                config.commander,
                rewardAmounts[i]
            );
            totalRewards += rewardAmounts[i];
        }
    }

    /**
     * @notice Checks if the Pendle oracle is ready for the given market
     * @dev This function checks the oracle state as per Pendle's documentation:
     *      https://docs.pendle.finance/Developers/Oracles/HowToIntegratePtAndLpOracle#third-initialize-the-oracle
     * @param _market The address of the Pendle market to check
     * @return bool Returns true if the oracle is ready, false otherwise
     * @custom:security-note Ensure that the oracle is properly initialized before using it in critical operations
     */
    function _isOracleReady(address _market) internal view returns (bool) {
        // Query the oracle state for the given market and oracle duration
        (
            bool increaseCardinalityRequired, // We ignore the second return value (current cardinality) as it's not needed for this check
            ,
            bool oldestObservationSatisfied
        ) = PendlePYLpOracle(oracle).getOracleState(_market, oracleDuration);

        // The oracle is ready if:
        // 1. No increase in cardinality is required (increaseCardinalityRequired is false)
        // 2. The oldest observation is satisfied (oldestObservationSatisfied is true)
        //
        // Note: We negate the result because the original conditions check for when the oracle is NOT ready
        return !(increaseCardinalityRequired || !oldestObservationSatisfied);
    }
}
