// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {Ark} from "../Ark.sol";
import {ArkParams} from "./BaseSwapArk.sol";
import {PendlePtArkConstructorParams} from "./PendlePTArk.sol";
import {ICurveSwap} from "../../interfaces/curve/ICurveSwap.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PERCENTAGE_100, Percentage, PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {TokenInput, TokenOutput} from "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import {LimitOrderData, IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {SwapData} from "@pendle/core-v2/contracts/router/swap-aggregator/IPSwapAggregator.sol";
import {ApproxParams} from "@pendle/core-v2/contracts/router/base/MarketApproxLib.sol";
import {IPPrincipalToken} from "@pendle/core-v2/contracts/interfaces/IPPrincipalToken.sol";
import {IPYieldToken} from "@pendle/core-v2/contracts/interfaces/IPYieldToken.sol";
import {IStandardizedYield} from "@pendle/core-v2/contracts/interfaces/IStandardizedYield.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {PendlePYLpOracle} from "@pendle/core-v2/contracts/oracles/PendlePYLpOracle.sol";
import {IPActionSwapPTV3} from "@pendle/core-v2/contracts/interfaces/IPActionSwapPTV3.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title CurveSwapPendlePtArk
 * @notice A contract for managing Curve swaps and Pendle PT (Principal Token) operations
 * @dev This contract extends the Ark contract and implements specific logic for Curve and Pendle interactions
 */
contract CurveSwapPendlePtArk is Ark {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
    uint256 public constant MIN_ORACLE_DURATION = 15 minutes;
    int128 public constant USDE_INDEX = 1;
    int128 public constant USDC_INDEX = 0;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ICurveSwap public curveSwap;
    address public marketAsset;
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
    uint256 public lowerEma = 0.9995 * 1e18;
    uint256 public upperEma = 1.00099 * 1e18;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct CurveSwapArkConstructorParams {
        address curvePool;
        address marketAsset;
    }

    struct BoardData {
        bytes swapForPtParams;
    }

    struct DisembarkData {
        bytes swapPtForTokenParams;
    }

    event MarketRolledOver(address newMarket);
    event SlippageUpdated(Percentage slippagePercentage);
    event OracleDurationUpdated(uint32 oracleDuration);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MarketExpired();
    error InvalidSwapType();
    error InvalidParamsLength();
    error InvalidFunctionSelector();
    error InvalidReceiver();
    error InvalidMarket();
    error EmaOutOfRange();
    error MarketExpirationTooClose();
    error LowerEmaNotLessThanUpperEma();
    error UpperEmaNotGreaterThanLowerEma();
    error InsufficientOutputAmount();
    error InvalidNextMarket();
    error InvalidMarketExpiry();
    error SlippagePercentageTooHigh(
        Percentage slippagePercentage,
        Percentage maxSlippagePercentage
    );
    error OracleDurationTooLow(
        uint32 oracleDuration,
        uint256 minOracleDuration
    );
    error InvalidAssetForSY();
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
    ) Ark(_params) {
        router = _pendlePtArkConstructorParams.router;
        oracle = _pendlePtArkConstructorParams.oracle;
        market = _pendlePtArkConstructorParams.market;
        oracleDuration = 30 minutes;
        slippagePercentage = PercentageUtils.fromFraction(15, 10000); // 0.15% default
        curveSwap = ICurveSwap(_curveSwapArkConstructorParams.curvePool);
        marketAsset = _curveSwapArkConstructorParams.marketAsset;
        _setupRouterParams();
        _updateMarketAndTokens(market);
        _updateMarketData();
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current exchange rate from the Curve pool
     * @return price The current exchange rate
     */
    function getExchangeRate() public view returns (uint256 price) {
        price = curveSwap.last_price(0);
        if (price > upperEma) {
            price = upperEma;
        }
        if (price < lowerEma) {
            price = lowerEma;
        }
        if (curveSwap.coins(1) != address(config.token)) {
            price = 1e36 / price;
        }
    }

    function getExchangeRateEma() public view returns (uint256 price) {
        price = curveSwap.ema_price(0);
        if (price > upperEma) {
            price = upperEma;
        }
        if (price < lowerEma) {
            price = lowerEma;
        }
        if (curveSwap.coins(1) != address(config.token)) {
            price = 1e36 / price;
        }
    }

    /**
     * @notice Calculates the total assets held by the Ark
     * @return The total assets in underlying token
     * @dev We handle this differently based on whether the market has expired:
     * 1. If the market has expired: return the exact PT / LP balance (1:1 ratio)
     * 2. If the market has not expired: subtract slippage from the calculated asset amount
     *
     * By subtracting slippage from total assets when the market is active, we ensure that:
     * a) We provide a conservative estimate of the Ark's value
     * b) We can always fulfill withdrawal requests, even in volatile market conditions
     * c) Users might receive slightly more than expected, which is beneficial for them
     */
    function totalAssets() public view override returns (uint256) {
        return
            (this.isMarketExpired())
                ? totalAssetsNoSplippage()
                : totalAssetsNoSplippage().subtractPercentage(
                    slippagePercentage
                );
    }

    function totalAssetsNoSplippage() public view returns (uint256) {
        uint256 assetAmount = (IERC20(PT).balanceOf(address(this)) *
            _ptToAssetRate()) / Constants.WAD;
        uint256 usdeToUsdcExchangeRate = getExchangeRate();
        uint256 usdcAmount = (assetAmount * 1e6) / usdeToUsdcExchangeRate;
        return usdcAmount;
    }
    /**
     * @notice Validate and decode swap for PT parameters
     * @param params Encoded swap parameters
     * @return receiver - address of the receiver
     * @return swapMarket - address of the swap market
     * @return minPtOut - minimum amount of PT out
     * @return guessPtOut - guess amount of PT out
     * @return input - token input
     * @return limit - limit order data
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
        if (selector != IPActionSwapPTV3.swapExactTokenForPt.selector)
            revert InvalidFunctionSelector();

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
     * @return receiver - address of the receiver
     * @return swapMarket - address of the swap market
     * @return exactPtIn - exact amount of PT in
     * @return output - token output
     * @return limit - limit order data
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
        if (selector != IPActionSwapPTV3.swapExactPtForToken.selector)
            revert InvalidFunctionSelector();

        (receiver, swapMarket, exactPtIn, output, limit) = abi.decode(
            params[4:],
            (address, address, uint256, TokenOutput, LimitOrderData)
        );
    }
    function isMarketExpired() public view returns (bool) {
        return block.timestamp >= marketExpiry;
    }
    /**
     * @notice Rescue tokens stuck in the contract
     * @param token Address of the token to rescue
     */
    function rescueToken(address token) public onlyGovernor {
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    /**
     * @notice Set the lower EMA threshold
     * @param _lowerEma New lower EMA threshold
     */
    function setLowerEma(uint256 _lowerEma) public onlyGovernor {
        if (_lowerEma >= upperEma) revert LowerEmaNotLessThanUpperEma();
        lowerEma = _lowerEma;
    }
    function nextMarket() public pure returns (address) {
        return 0x281fE15fd3E08A282f52D5cf09a4d13c3709E66D;
    }
    /**
     * @notice Set the upper EMA threshold
     * @param _upperEma New upper EMA threshold
     */
    function setUpperEma(uint256 _upperEma) public onlyGovernor {
        if (_upperEma <= lowerEma) revert UpperEmaNotGreaterThanLowerEma();
        upperEma = _upperEma;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to deposit tokens for Ark tokens
     * @param _amount Amount of tokens to deposit
     * @param data Additional data for the deposit
     */
    function _depositFleetTokenForArkToken(
        uint256 _amount,
        bytes calldata data
    ) internal shouldBuy {
        BoardData memory boardData = abi.decode(data, (BoardData));
        if (this.isMarketExpired()) {
            revert MarketExpired();
        }

        (
            address receiver,
            address swapMarket,
            uint256 minPtOut,
            ApproxParams memory guessPtOut,
            TokenInput memory input,
            LimitOrderData memory limit
        ) = this.validateAndDecodeSwapForPtParams(boardData.swapForPtParams);

        if (receiver != address(this)) revert InvalidReceiver();
        if (swapMarket != market) revert InvalidMarket();
        IERC20(config.token).approve(address(router), _amount);
        IPAllActionV3(router).swapExactTokenForPt(
            receiver,
            swapMarket,
            minPtOut,
            guessPtOut,
            input,
            limit
        );
    }

    /**
     * @notice Internal function to withdraw Ark tokens for tokens
     * @param _amount Amount of Ark tokens to withdraw
     * @param data Additional data for the withdrawal
     */
    function _withdrawArkTokenForToken(
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

        IERC20(PT).approve(address(router), exactPtIn);
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
        // todo: if market expired then revert - we need to allow this fucntion to execture - to rollover
        _rolloverIfNeeded();
        _depositFleetTokenForArkToken(amount, data);
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

        if (this.isMarketExpired()) {
            _redeemTokenFromPtPostExpiry(amount, amount);
            // todo : swap for usdc or new method to withdraw market asset (usde)
        } else {
            _withdrawArkTokenForToken(amount, data);
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
    function _validateBoardData(bytes calldata data) internal view override {
        // Implementation left empty intentionally
    }

    /**
     * @notice Validate disembark data
     * @param data Data to validate
     */
    function _validateDisembarkData(
        bytes calldata data
    ) internal view override {
        // Implementation left empty intentionally
    }

    /**
     * @notice Set up router parameters
     */
    function _setupRouterParams() internal {
        routerParams.guessMax = type(uint256).max;
        routerParams.maxIteration = 256;
        routerParams.eps = 1e15; // 0.1% precision
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
            !IStandardizedYield(SY).isValidTokenIn(address(marketAsset)) ||
            !IStandardizedYield(SY).isValidTokenOut(address(marketAsset))
        ) {
            revert InvalidAssetForSY();
        }
        _updateMarketData();
    }
    function _ptToAssetRate() internal view returns (uint256) {
        return
            PendlePYLpOracle(oracle).getPtToAssetRate(market, oracleDuration);
    }
    function _assetToArkTokens(uint256 amount) internal view returns (uint256) {
        return (amount * Constants.WAD) / _ptToAssetRate();
    }

    /**
     * @notice Deposits tokens and swaps them for Principal Tokens (PT)
     * @param _amount Amount of tokens to deposit
     * @dev Checks for market expiry, calculates minimum PT output with slippage, and executes the swap
     * @dev This function performs the following steps:
     * 1. Check if the market has expired, revert if it has
     * 2. Calculate the minimum PT output based on the current exchange rate and slippage
     * 3. Prepare the input token data for the Pendle router
     * 4. Execute the swap using Pendle's router
     *
     * We use slippage protection here to ensure we receive at least the calculated minimum PT tokens.
     * This protects against sudden price movements between our calculation and the actual swap execution.
     */
    function _depositMarketAssetForPt(uint256 _amount) internal {
        uint256 minPTout = _assetToArkTokens(_amount).subtractPercentage(
            slippagePercentage
        );

        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(marketAsset),
            netTokenIn: _amount,
            tokenMintSy: address(marketAsset),
            pendleSwap: address(0),
            swapData: emptySwap
        });

        IERC20(marketAsset).approve(address(router), _amount);
        IPAllActionV3(router).swapExactTokenForPt(
            address(this),
            market,
            minPTout,
            routerParams,
            tokenInput,
            emptyLimitOrderData
        );
    }

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
        _redeemTokenFromPtPostExpiry(ptBalance, ptBalance);
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

    function _redeemTokenFromPtPostExpiry(
        uint256 ptAmount,
        uint256 minTokenOut
    ) internal {
        if (ptAmount > 0) {
            IERC20(PT).approve(address(router), ptAmount);
            IPAllActionV3(router).redeemPyToSy(
                address(this),
                address(YT),
                ptAmount,
                minTokenOut
            );
        }

        uint256 syBalance = IERC20(SY).balanceOf(address(this));
        if (syBalance > 0) {
            uint256 tokensToRedeem = IStandardizedYield(SY).previewRedeem(
                address(marketAsset),
                syBalance
            );
            IStandardizedYield(SY).redeem(
                address(this),
                syBalance,
                address(marketAsset),
                tokensToRedeem,
                false
            );
        }
    }

    /**
     * @notice Check if trading should be allowed
     */
    function _shouldTrade() internal view {
        if (!onlyWhenBetween(getExchangeRateEma(), lowerEma, upperEma))
            revert EmaOutOfRange();
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
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the slippage tolerance
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

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to check if buying should be allowed
     * @dev This modifier ensures that the market is not expired and that the market expiration is not too close to the current block timestamp.
     */
    modifier shouldBuy() {
        _shouldTrade();
        if (marketExpiry <= block.timestamp + 1 days)
            revert MarketExpirationTooClose();
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
