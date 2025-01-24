// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICurveSwap} from "../../interfaces/curve/ICurveSwap.sol";
import {Ark, ArkParams} from "../Ark.sol";

import {CurveExchangeRateProvider} from "../../utils/exchangeRateProvider/CurveExchangeRateProvider.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPActionSwapPTV3} from "@pendle/core-v2/contracts/interfaces/IPActionSwapPTV3.sol";
import {TokenInput, TokenOutput} from "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import {IPAllActionV3, LimitOrderData} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {IPPrincipalToken} from "@pendle/core-v2/contracts/interfaces/IPPrincipalToken.sol";
import {IPYieldToken} from "@pendle/core-v2/contracts/interfaces/IPYieldToken.sol";
import {IStandardizedYield} from "@pendle/core-v2/contracts/interfaces/IStandardizedYield.sol";
import {PendlePYLpOracle} from "@pendle/core-v2/contracts/oracles/PendlePYLpOracle.sol";
import {ApproxParams} from "@pendle/core-v2/contracts/router/base/MarketApproxLib.sol";
import {SwapData} from "@pendle/core-v2/contracts/router/swap-aggregator/IPSwapAggregator.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {PERCENTAGE_100, Percentage, PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title PendlePtOracleArk
 * @dev An Ark implementation for Pendle Principal Tokens with oracle-based pricing.
 *
 * This contract combines functionality from Ark, CurveExchangeRateProvider,
 * and Pendle-specific operations to create a yield-generating vault that
 * works with Pendle's Principal Tokens (PT). It manages deposits, withdrawals,
 * and automatic rollovers between different Pendle markets.
 *
 * Terms:
 *
 * - Ark asset (also Fleet asset eg USDC)
 * - Market asset (the asset used by a Pendle PT market eg USDe)
 * - Pendle PT (the Pendle principal token)
 *
 * Key features:
 * - Handles boarding (depositing) and disembarking (withdrawing) of tokens
 * - Manages conversion between Ark assets and Pendle's Principal Tokens
 * - Implements automatic rollover to new markets upon expiry
 * - Uses an oracle for accurate PT pricing
 * - Leverages Curve as a price oracle for stablecoins
 * - Implements slippage protection for trades
 * - Includes EMA-based price bounds for trade execution
 * - Supports reward token harvesting from Pendle markets
 * - Provides emergency withdrawal functionality for expired markets
 *
 * Security features:
 * - Ensures markets aren't too close to expiry when boarding
 * - Validates receiver addresses and market consistency
 * - Implements slippage control with configurable tolerances
 * - Includes oracle duration checks for price reliability
 * - Enforces market rollover conditions and validation
 *
 * The contract is designed to provide yield opportunities by leveraging
 * Pendle's Principal Tokens while ensuring accurate pricing and efficient
 * fund management. The rollover mechanism allows for continuous yield
 * generation across multiple market cycles. By combining multiple
 * functionalities, it offers a sophisticated and flexible system for
 * managing yield-generating strategies in the DeFi ecosystem.
 *
 * Integration points:
 * - Pendle Router: For PT swaps and market interactions
 * - Curve: For stablecoin exchange rates
 * - Pendle Oracle: For PT pricing
 * - ERC20: For token transfers and approvals
 */
contract PendlePtOracleArk is Ark, CurveExchangeRateProvider {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
    uint256 public constant MIN_ORACLE_DURATION = 15 minutes;
    uint256 public constant MAX_ORACLE_DURATION = 1 hours;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable marketAsset;
    address public market;
    address public immutable router;
    address public nextMarket;
    address public immutable oracle;
    uint8 public immutable configTokenDecimals;
    uint8 public immutable marketAssetDecimals;
    uint8 public ptDecimals;
    uint32 public oracleDuration;
    IStandardizedYield public SY;
    IPPrincipalToken public PT;
    IPYieldToken public YT;
    Percentage public slippagePercentage;
    uint256 public marketExpiry;
    ApproxParams public routerParams;
    LimitOrderData emptyLimitOrderData;
    SwapData public emptySwap;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CurveSwapArkConstructorParams {
        address curvePool;
        uint256 basePrice;
        Percentage lowerPercentageRange;
        Percentage upperPercentageRange;
    }

    struct PendlePtArkConstructorParams {
        address market;
        address oracle;
        address router;
    }

    struct BoardData {
        bytes swapForPtParams;
    }

    struct DisembarkData {
        bytes swapPtForTokenParams;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketRolledOver(address newMarket);
    event SlippageUpdated(Percentage slippagePercentage);
    event OracleDurationUpdated(uint32 oracleDuration);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MarketExpired();
    error InvalidParamsLength();
    error InvalidFunctionSelector();
    error InvalidReceiver();
    error InvalidMarket();
    error EmaOutOfRange();
    error MarketExpirationTooClose();
    error InsufficientOutputAmount();
    error InvalidNextMarket();
    error SlippagePercentageTooHigh(
        Percentage slippagePercentage,
        Percentage maxSlippagePercentage
    );
    error OracleDurationTooLow(
        uint32 oracleDuration,
        uint256 minOracleDuration
    );
    error OracleDurationTooHigh(
        uint32 oracleDuration,
        uint256 maxOracleDuration
    );
    error InvalidAssetForSY();
    error InvalidRouterAddress(address router);
    error InvalidOracleAddress(address oracle);
    error InvalidMarketAddress(address market);
    error InvalidAsset(address asset);
    error InvalidAmount();
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param _params General Ark parameters
     * @param _pendlePtArkConstructorParams Pendle PT Ark specific parameters
     * @param _curveSwapArkConstructorParams Curve swap specific parameters
     */
    constructor(
        ArkParams memory _params,
        PendlePtArkConstructorParams memory _pendlePtArkConstructorParams,
        CurveSwapArkConstructorParams memory _curveSwapArkConstructorParams
    )
        Ark(_params)
        CurveExchangeRateProvider(
            _curveSwapArkConstructorParams.curvePool,
            _getSyAssetAddress(_pendlePtArkConstructorParams.market),
            _curveSwapArkConstructorParams.lowerPercentageRange,
            _curveSwapArkConstructorParams.upperPercentageRange,
            _curveSwapArkConstructorParams.basePrice
        )
    {
        if (_pendlePtArkConstructorParams.router == address(0)) {
            revert InvalidRouterAddress(_pendlePtArkConstructorParams.router);
        }
        router = _pendlePtArkConstructorParams.router;
        if (_pendlePtArkConstructorParams.oracle == address(0)) {
            revert InvalidOracleAddress(_pendlePtArkConstructorParams.oracle);
        }
        oracle = _pendlePtArkConstructorParams.oracle;
        if (_pendlePtArkConstructorParams.market == address(0)) {
            revert InvalidMarketAddress(_pendlePtArkConstructorParams.market);
        }
        oracleDuration = 30 minutes;
        slippagePercentage = PercentageUtils.fromFraction(50, 10000); // 0.5% default
        marketAsset = _getSyAssetAddress(_pendlePtArkConstructorParams.market);
        configTokenDecimals = IERC20Extended(address(config.asset)).decimals();
        marketAssetDecimals = IERC20Extended(marketAsset).decimals();
        _setupRouterParams();
        _updateMarketAndTokens(_pendlePtArkConstructorParams.market);
    }

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev PendlePtOracleArk is not withdrawable by default
     */
    function _withdrawableTotalAssets()
        internal
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    /**
     * @notice Helper function to get the SY asset address from a market
     * @param _market The market address to query
     * @return assetAddress The asset address from the SY contract
     */
    function _getSyAssetAddress(
        address _market
    ) internal view returns (address assetAddress) {
        (IStandardizedYield sy, , ) = IPMarketV3(_market).readTokens();
        (, assetAddress, ) = sy.assetInfo();
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the total assets held by the Ark
     * @return The total assets in underlying token
     * @dev We handle this differently based on whether the market has expired:
     * 1. If the market has expired: return the exact PT / LP balance (1:1 ratio)
     * 2. If the market has not expired: subtract slippage from the calculated asset amount
     */
    function totalAssets() public view override returns (uint256) {
        return
            (this.isMarketExpired())
                ? totalAssetsNoSlippage()
                : totalAssetsNoSlippage().subtractPercentage(
                    slippagePercentage
                );
    }

    /**
     * @notice Calculates the total assets held by the Ark without considering slippage
     * @return The total assets in underlying token without slippage
     */
    function totalAssetsNoSlippage() public view returns (uint256) {
        uint256 assetAmount = (IERC20(PT).balanceOf(address(this)) *
            _ptToMarketAssetRate()) / Constants.WAD;
        uint256 marketAssetToArkTokenExchangeRate = getSafeExchangeRateEma();
        uint256 arkTokenAmount = (assetAmount * 10 ** configTokenDecimals) /
            marketAssetToArkTokenExchangeRate;
        return arkTokenAmount;
    }

    /**
     * @notice Validate and decode swap for PT parameters
     * @param params Encoded swap parameters
     * @return receiver Address of the receiver
     * @return swapMarket Address of the swap market
     * @return minPtOut Minimum amount of PT out
     * @return guessPtOut Guess amount of PT out
     * @return input Token input
     * @return limit Limit order data
     */
    function validateAndDecodeSwapForPtParams(
        bytes calldata params
    )
        external
        pure
        returns (
            address receiver,
            address swapMarket,
            uint256 minPtOut,
            ApproxParams memory guessPtOut,
            TokenInput memory input,
            LimitOrderData memory limit
        )
    {
        if (params.length < 4) revert InvalidParamsLength();

        bytes4 selector = bytes4(params[:4]);
        if (selector != IPActionSwapPTV3.swapExactTokenForPt.selector) {
            revert InvalidFunctionSelector();
        }

        (receiver, swapMarket, minPtOut, guessPtOut, input, limit) = abi.decode(
            params[4:],
            (
                address,
                address,
                uint256,
                ApproxParams,
                TokenInput,
                LimitOrderData
            )
        );
    }

    /**
     * @notice Validate and decode swap PT for token parameters
     * @param params Encoded swap parameters
     * @return receiver Address of the receiver
     * @return swapMarket Address of the swap market
     * @return exactPtIn Exact amount of PT in
     * @return output Token output
     * @return limit Limit order data
     */
    function validateAndDecodeSwapPtForTokenParams(
        bytes calldata params
    )
        external
        pure
        returns (
            address receiver,
            address swapMarket,
            uint256 exactPtIn,
            TokenOutput memory output,
            LimitOrderData memory limit
        )
    {
        if (params.length < 4) revert InvalidParamsLength();

        bytes4 selector = bytes4(params[:4]);
        if (selector != IPActionSwapPTV3.swapExactPtForToken.selector) {
            revert InvalidFunctionSelector();
        }

        (receiver, swapMarket, exactPtIn, output, limit) = abi.decode(
            params[4:],
            (address, address, uint256, TokenOutput, LimitOrderData)
        );
    }

    /**
     * @notice Check if the current market has expired
     * @return bool True if the market has expired, false otherwise
     */
    function isMarketExpired() public view returns (bool) {
        return block.timestamp >= marketExpiry;
    }

    function withdrawExpiredMarket() public onlyGovernor {
        if (this.isMarketExpired()) {
            uint256 amount = IERC20(PT).balanceOf(address(this));
            _redeemMarketAssetFromPtPostExpiry(amount, amount);
            IERC20(marketAsset).safeTransfer(
                msg.sender,
                IERC20(marketAsset).balanceOf(address(this))
            );
        }
    }

    /**
     * @notice Rollover to a new market if needed
     */
    function rolloverIfNeeded() public {
        _rolloverIfNeeded();
    }

    /**
     * @notice Set the next market
     * @param _nextMarket Address of the next market
     */
    function setNextMarket(address _nextMarket) public onlyGovernor {
        nextMarket = _nextMarket;
    }

    /**
     * @notice Sets the slippage tolerance
     * @param _slippagePercentage New slippage tolerance
     */
    function setSlippagePercentage(
        Percentage _slippagePercentage
    ) external onlyCurator(config.commander) {
        if (_slippagePercentage > MAX_SLIPPAGE_PERCENTAGE) {
            revert SlippagePercentageTooHigh(
                _slippagePercentage,
                MAX_SLIPPAGE_PERCENTAGE
            );
        }
        slippagePercentage = _slippagePercentage;
        emit SlippageUpdated(_slippagePercentage);
    }

    function setEmaRange(
        Percentage _lowerPercentageRange,
        Percentage _upperPercentageRange
    ) external onlyCurator(config.commander) {
        _setEmaRange(_lowerPercentageRange, _upperPercentageRange);
    }

    function setBasePrice(
        uint256 _basePrice
    ) external onlyCurator(config.commander) {
        _setBasePrice(_basePrice);
    }

    /**
     * @notice Sets the oracle duration
     * @param _oracleDuration New oracle duration
     */
    function setOracleDuration(
        uint32 _oracleDuration
    ) external onlyCurator(config.commander) {
        if (_oracleDuration < MIN_ORACLE_DURATION) {
            revert OracleDurationTooLow(_oracleDuration, MIN_ORACLE_DURATION);
        }
        if (_oracleDuration > MAX_ORACLE_DURATION) {
            revert OracleDurationTooHigh(_oracleDuration, MAX_ORACLE_DURATION);
        }
        oracleDuration = _oracleDuration;
        emit OracleDurationUpdated(_oracleDuration);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to swap fleet asset for Principal Tokens (PT)
     * @param _amount Amount of fleet asset to swap for PT
     * @param data Additional data for the swap
     * @dev This function is called during the boarding process
     */
    function _swapFleetAssetForPt(
        uint256 _amount,
        bytes calldata data
    ) internal shouldBuy {
        BoardData memory boardData = abi.decode(data, (BoardData));
        (
            address receiver,
            address swapMarket,
            uint256 minPtOut,
            ApproxParams memory guessPtOut,
            TokenInput memory input,
            LimitOrderData memory limit
        ) = this.validateAndDecodeSwapForPtParams(boardData.swapForPtParams);

        if (input.tokenIn != address(config.asset)) {
            revert InvalidAsset(address(config.asset));
        }
        if (input.netTokenIn != _amount) revert InvalidAmount();
        if (receiver != address(this)) revert InvalidReceiver();
        if (swapMarket != market) revert InvalidMarket();

        IERC20(config.asset).forceApprove(router, _amount);
        (uint256 netPtOut, , ) = IPAllActionV3(router).swapExactTokenForPt(
            receiver,
            swapMarket,
            minPtOut,
            guessPtOut,
            input,
            limit
        );

        uint256 expectedPtAmount = _fleetAssetToPt(_amount);
        uint256 minExpectedPtAmount = expectedPtAmount.subtractPercentage(
            slippagePercentage
        );

        if (netPtOut < minExpectedPtAmount) revert InsufficientOutputAmount();
    }

    /**
     * @notice Internal function to swap Principal Tokens (PT) for fleet asset
     * @param _amount Minimum amount of fleet asset to receive from swap
     * @param data Additional data for the swap
     * @dev This function is called during the disembarking process
     */
    function _swapPtForFleetAsset(
        uint256 _amount,
        bytes calldata data
    ) internal {
        DisembarkData memory disembarkData = abi.decode(data, (DisembarkData));
        if (this.isMarketExpired()) revert MarketExpired();

        (
            address receiver,
            address swapMarket,
            uint256 exactPtIn,
            TokenOutput memory output,
            LimitOrderData memory limit
        ) = this.validateAndDecodeSwapPtForTokenParams(
                disembarkData.swapPtForTokenParams
            );

        if (receiver != address(this)) revert InvalidReceiver();
        if (swapMarket != market) revert InvalidMarket();
        if (_amount < output.minTokenOut) revert InsufficientOutputAmount();
        if (output.tokenOut != address(config.asset)) {
            revert InvalidAsset(address(config.asset));
        }

        uint256 expectedPtAmount = _fleetAssetToPt(_amount);
        uint256 maxPtAmount = expectedPtAmount.addPercentage(
            slippagePercentage
        );

        if (exactPtIn > maxPtAmount) revert InvalidAmount();

        IERC20(PT).forceApprove(router, exactPtIn);
        IPAllActionV3(router).swapExactPtForToken(
            receiver,
            swapMarket,
            exactPtIn,
            output,
            limit
        );
    }

    /**
     * @notice Internal function to board (deposit) tokens
     * @param amount Amount of tokens to board
     * @param data Additional data for boarding
     */
    function _board(uint256 amount, bytes calldata data) internal override {
        _rolloverIfNeeded();
        _swapFleetAssetForPt(amount, data);
    }

    /**
     * @notice Internal function to disembark (withdraw) tokens
     * @param amount Amount of tokens to disembark
     * @param data Additional data for disembarking
     */
    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override shouldTrade {
        _rolloverIfNeeded();
        if (!this.isMarketExpired()) {
            _swapPtForFleetAsset(amount, data);
        }
    }

    /**
     * @notice Internal function to harvest rewards
     * @return rewardTokens The addresses of the reward tokens
     * @return rewardAmounts The amounts of the reward tokens
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = IPMarketV3(market).getRewardTokens();
        rewardAmounts = IPMarketV3(market).redeemRewards(address(this));
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).safeTransfer(raft(), rewardAmounts[i]);
        }
    }

    /**
     * @notice Validate board data
     * @param data Data to validate
     */
    function _validateBoardData(bytes calldata data) internal view override {}

    /**
     * @notice Validate disembark data
     * @param data Data to validate
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal view override {}

    /**
     * @notice Set up router parameters
     */
    function _setupRouterParams() internal {
        routerParams.guessMax = Constants.MAX_UINT256;
        routerParams.maxIteration = 256;
        routerParams.eps = Constants.WAD / 1000; // 0.1% precision
    }

    /**
     * @notice Update market data
     */
    function _updateMarketData() internal {
        marketExpiry = IPMarketV3(market).expiry();
    }

    /**
     * @notice Update market and token addresses
     * @param newMarket Address of the new market
     */
    function _updateMarketAndTokens(address newMarket) internal {
        market = newMarket;
        (SY, PT, YT) = IPMarketV3(newMarket).readTokens();

        if (
            !IStandardizedYield(SY).isValidTokenIn(marketAsset) ||
            !IStandardizedYield(SY).isValidTokenOut(marketAsset)
        ) {
            revert InvalidAssetForSY();
        }
        ptDecimals = PT.decimals();
        _updateMarketData();
    }

    /**
     * @notice Get the PT to asset rate
     * @return The PT to asset rate
     */
    function _ptToMarketAssetRate() internal view returns (uint256) {
        return
            PendlePYLpOracle(oracle).getPtToAssetRate(market, oracleDuration);
    }

    /**
     * @notice Convert market asset amount to Principal Tokens (PT)
     * @param amount Amount of market assets to convert
     * @return The equivalent amount of Principal Tokens (PT)
     */
    function _marketAssetToPt(uint256 amount) internal view returns (uint256) {
        uint256 scaleFactor = 10 ** (18 + ptDecimals - marketAssetDecimals);
        return (amount * scaleFactor) / _ptToMarketAssetRate();
    }

    /**
     * @notice Converts fleet asset amount to PT amount
     * @param fleetAssetAmount Amount of fleet assets to convert
     * @return ptAmount The equivalent amount of Principal Tokens
     */
    function _fleetAssetToPt(
        uint256 fleetAssetAmount
    ) internal view returns (uint256) {
        uint256 marketAssetToArkTokenExchangeRate = getSafeExchangeRateEma();
        uint256 marketAssetAmount = (fleetAssetAmount *
            marketAssetToArkTokenExchangeRate) / (10 ** configTokenDecimals);

        return _marketAssetToPt(marketAssetAmount);
    }

    /**
     * @notice Deposits tokens and swaps them for Principal Tokens (PT)
     * @param _amount Amount of tokens to deposit
     */
    function _depositMarketAssetForPt(uint256 _amount) internal {
        uint256 minPTout = _marketAssetToPt(_amount).subtractPercentage(
            slippagePercentage
        );

        TokenInput memory tokenInput = TokenInput({
            tokenIn: marketAsset,
            netTokenIn: _amount,
            tokenMintSy: marketAsset,
            pendleSwap: address(0),
            swapData: emptySwap
        });

        IERC20(marketAsset).forceApprove(router, _amount);
        IPAllActionV3(router).swapExactTokenForPt(
            address(this),
            market,
            minPTout,
            routerParams,
            tokenInput,
            emptyLimitOrderData
        );
    }

    /**
     * @notice Rollover to a new market if needed
     */
    function _rolloverIfNeeded() internal {
        if (block.timestamp < marketExpiry) return;

        address newMarket = this.nextMarket();
        if (newMarket == address(0) || newMarket == market) {
            revert InvalidNextMarket();
        }

        if (!_isOracleReady(newMarket)) {
            return;
        }
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));
        _redeemMarketAssetFromPtPostExpiry(ptBalance, ptBalance);
        _updateMarketAndTokens(newMarket);
        _depositMarketAssetForPt(ptBalance);

        emit MarketRolledOver(newMarket);
    }

    /**
     * @notice Checks if the Pendle oracle is ready for the given market
     * @param _market The address of the Pendle market to check
     * @return bool Returns true if the oracle is ready, false otherwise
     */
    function _isOracleReady(address _market) internal view returns (bool) {
        (
            bool increaseCardinalityRequired,
            ,
            bool oldestObservationSatisfied
        ) = PendlePYLpOracle(oracle).getOracleState(_market, oracleDuration);
        return !increaseCardinalityRequired && oldestObservationSatisfied;
    }

    /**
     * @notice Redeem tokens from PT post expiry
     * @param ptAmount Amount of PT to redeem
     * @param minTokenOut Minimum amount of tokens to receive
     */
    function _redeemMarketAssetFromPtPostExpiry(
        uint256 ptAmount,
        uint256 minTokenOut
    ) internal {
        if (ptAmount > 0) {
            IERC20(PT).forceApprove(router, ptAmount);
            TokenOutput memory tokenOutput = TokenOutput({
                tokenOut: marketAsset,
                minTokenOut: minTokenOut,
                tokenRedeemSy: marketAsset,
                pendleSwap: address(0),
                swapData: emptySwap
            });
            IPAllActionV3(router).redeemPyToToken(
                address(this),
                address(YT),
                ptAmount,
                tokenOutput
            );
        }
    }

    /**
     * @notice Check if trading should be allowed
     */
    function _shouldTrade() internal view {
        if (
            !onlyWhenBetween(
                getExchangeRateEma(),
                getLowerBound(),
                getUpperBound()
            )
        ) {
            revert EmaOutOfRange();
        }
    }

    /**
     * @notice Check if a number is between two values
     * @param number The number to check
     * @param lower The lower bound
     * @param upper The upper bound
     * @return bool Whether the number is between the bounds
     */
    function onlyWhenBetween(
        uint256 number,
        uint256 lower,
        uint256 upper
    ) internal pure returns (bool) {
        return number >= lower && number <= upper;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to check if buying should be allowed
     * @dev This modifier ensures that the market is not expired and that the market expiration is not too close to the
     * current block timestamp.
     */
    modifier shouldBuy() {
        _shouldTrade();
        if (marketExpiry <= block.timestamp + 20 days) {
            revert MarketExpirationTooClose();
        }
        _;
    }

    /**
     * @notice Modifier to check if trading should be allowed
     */
    modifier shouldTrade() {
        _shouldTrade();
        _;
    }
}
