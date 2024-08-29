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
import {MarketExpired, NoValidNextMarket, OracleDurationTooLow, SlippagePercentageTooHigh, InvalidAssetForSY} from "../../errors/arks/PendleArkErrors.sol";
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
     * @dev This function performs the following steps:
     * 1. Check if the market has expired. If so, revert the transaction.
     * 2. Calculate the minimum LP tokens to receive based on the input amount and slippage:
     *    - We use the Pendle LP oracle to get the current LP to asset rate.
     *    - We convert the input amount to LP tokens using this rate.
     *    - We subtract the slippage percentage from this amount to set a minimum acceptable output.
     * 3. Prepare the input token data for the Pendle router.
     * 4. Call the Pendle router to add liquidity using a single token (our asset).
     *
     * Slippage protection ensures we receive at least the calculated minimum LP tokens.
     * This guards against price movements between our calculation and the actual swap execution.
     * The use of a TWAP oracle helps mitigate the risk of short-term price manipulations.
     */
    function _depositTokenForLp(uint256 _amount) internal {
        if (block.timestamp >= marketExpiry) {
            revert MarketExpired();
        }
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
     * @dev This function handles redemptions differently based on whether the market has expired:
     * 1. If the market has expired:
     *    - We use the input amount directly as the minimum token output.
     *    - We convert the input amount to LP tokens without applying slippage.
     * 2. If the market has not expired:
     *    - We calculate the LP amount needed to redeem the requested asset amount, adding slippage.
     *    - We use the lesser of the calculated LP amount and the current LP balance.
     *    - We use the input amount as the minimum token output.
     * 3. In both cases, we call the internal _removeLiquidity function to execute the redemption.
     *
     * Slippage protection is applied differently before and after expiry:
     * - Before expiry: We add slippage when calculating LP tokens to ensure we have enough.
     * - After expiry: We don't apply slippage as the redemption rate is fixed at 1:1.
     */
    function _redeemTokenFromLp(uint256 amount) internal {
        if (block.timestamp >= marketExpiry) {
            uint256 minTokenOut = amount;
            uint256 lpAmount = _assetToLP(amount);
            _removeLiquidity(lpAmount, minTokenOut);
        } else {
            uint256 lpBalance = IERC20(market).balanceOf(address(this));

            // Calculate the LP amount needed to redeem the requested asset amount, accounting for slippage
            uint256 withdrawAmountInLp = _assetToLP(amount).addPercentage(
                slippagePercentage
            );
            // Use the lesser of the calculated LP amount and the current LP balance /// TODO: check that thoroughly if it can be explited
            uint256 lpAmount = (withdrawAmountInLp > lpBalance)
                ? lpBalance
                : withdrawAmountInLp;

            _removeLiquidity(lpAmount, amount);
        }
    }

    /**
     * @notice Internal function to remove liquidity from the Pendle market
     * @param lpAmount Amount of LP tokens to remove
     * @param minTokenOut Minimum amount of underlying tokens to receive
     * @dev This function prepares the token output data and calls the Pendle router to remove liquidity
     */
    function _removeLiquidity(uint256 lpAmount, uint256 minTokenOut) internal {
        TokenOutput memory tokenOutput = TokenOutput({
            tokenOut: address(config.token),
            minTokenOut: minTokenOut,
            tokenRedeemSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });
        IPAllActionV3(router).removeLiquiditySingleToken(
            address(this),
            market,
            lpAmount,
            tokenOutput,
            emptyLimitOrderData
        );
    }
    /**
     * @notice Redeems all LP and SY to underlying tokens
     */
    function _redeemAllTokensFromLp() internal {
        uint256 lpBalance = _balanceOfLP();
        uint256 expectedTokenOut = _LPtoAsset(lpBalance);

        if (lpBalance > 0) {
            _removeLiquidity(lpBalance, expectedTokenOut);
        }
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
     * @dev We handle this differently based on whether the market has expired:
     * 1. After expiry: We return the full amount of assets held by the LP without applying slippage.
     * 2. Before expiry: We decrease the total assets by the allowed slippage.
     *
     * Subtracting slippage before expiry provides a conservative estimate of total assets.
     * This ensures we can always fulfill withdrawal requests, even in volatile market conditions.
     * The actual redeemed amount may be higher, which is beneficial for users.
     */
    function totalAssets() public view override returns (uint256) {
        return
            (block.timestamp >= marketExpiry)
                ? _LPtoAsset(_balanceOfLP())
                : _LPtoAsset(_balanceOfLP()).subtractPercentage(
                    slippagePercentage
                );
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

        if (!_isOracleReady(newMarket)) {
            return;
        }
        _redeemAllTokensFromLp();
        _updateMarketAndTokens(newMarket);
        _updateMarketData();

        emit MarketRolledOver(newMarket);
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
     * @dev We use the Pendle oracle to get the current LP to asset rate.
     * This rate is used to calculate the equivalent asset amount for a given LP amount.
     * Since the oracle is TWAP based, the rate lag is expected.
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
     * @dev There is no reverse operation for `getLpToAssetRate` in the Pendle oracle,
     * so we invert the LP to asset rate to calculate the asset to LP rate.
     * This is an approximation and may not be exact due to rounding errors.
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
