// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IStandardizedYield} from "@pendle/core-v2/contracts/interfaces/IStandardizedYield.sol";
import {IPPrincipalToken} from "@pendle/core-v2/contracts/interfaces/IPPrincipalToken.sol";
import {IPYieldToken} from "@pendle/core-v2/contracts/interfaces/IPYieldToken.sol";
import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {PendlePYLpOracle} from "@pendle/core-v2/contracts/oracles/PendlePYLpOracle.sol";
import {ApproxParams} from "@pendle/core-v2/contracts/router/base/MarketApproxLib.sol";
import {LimitOrderData, TokenOutput, TokenInput} from "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import {SwapData} from "@pendle/core-v2/contracts/router/swap-aggregator/IPSwapAggregator.sol";
import {Percentage, PercentageUtils, PERCENTAGE_100} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {OracleNotReady, NoValidNextMarket, OracleDurationTooLow, SlippagePercentageTooHigh, InvalidAssetForSY} from "../../errors/arks/PendleArkErrors.sol";
import {IPendleArkEvents} from "../../events/arks/IPendleArkEvents.sol";

/**
 * @title PendlePTArk
 * @notice This contract manages a Pendle Principal Token (PT) strategy within the Ark system
 * @dev Inherits from Ark and implements Pendle-specific logic for PT positions
 */
contract PendlePTArk is Ark, IPendleArkEvents {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    // Constants
    Percentage private constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
    uint256 private constant MIN_ORACLE_DURATION = 900; // 15 minutes

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

    constructor(
        address _asset,
        address _market,
        address _oracle,
        address _router,
        ArkParams memory _params
    ) Ark(_params) {
        // Initialize contract state variables
        market = _market;
        router = _router;
        oracle = _oracle;
        oracleDuration = 30 minutes; // Default oracle duration
        slippagePercentage = PercentageUtils.fromFraction(5, 1000); // 0.5% default slippage

        // Get token addresses from the Pendle market
        (SY, PT, YT) = IPMarketV3(_market).readTokens();

        // Ensure the underlying asset is compatible with the Standardized Yield (SY) token
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
     * @notice Internal function to set up router parameters for Pendle swaps
     * @dev These parameters are used to control the approximation algorithm in Pendle's router
     */
    function _setupRouterParams() private {
        routerParams.guessMax = type(uint256).max; // Maximum guess for binary search
        routerParams.maxIteration = 256; // Maximum iterations for approximation
        routerParams.eps = 1e15; // 0.1% precision (1e15 = 0.001 * 1e18)
    }

    /**
     * @notice Set up token approvals for Pendle interactions
     * @param _asset Address of the underlying asset
     */
    function _setupApprovals(address _asset) private {
        IERC20(_asset).forceApprove(address(router), type(uint256).max);
        IERC20(SY).forceApprove(router, type(uint256).max);
        IERC20(PT).forceApprove(router, type(uint256).max);
    }

    /**
     * @notice Deposits assets into the Ark and converts them to Principal Tokens (PT)
     * @param amount Amount of assets to deposit
     */
    function _board(uint256 amount) internal override {
        _rolloverIfNeeded();
        _depositTokenForPt(amount);
    }

    /**
     * @notice Withdraws assets from the Ark by redeeming Principal Tokens (PT)
     * @param amount Amount of assets to withdraw
     */
    function _disembark(uint256 amount) internal override {
        _rolloverIfNeeded();
        _redeemTokenFromPt(amount);
    }

    /**
     * @notice Deposits tokens and swaps them for Principal Tokens (PT)
     * @param _amount Amount of tokens to deposit
     * @dev This function calculates the minimum PT output based on the current exchange rate and slippage,
     *      then performs the swap using Pendle's router
     */
    function _depositTokenForPt(uint256 _amount) internal {
        // Calculate the minimum PT output, accounting for slippage
        uint256 minPTout = _SYtoPT(_amount).subtractPercentage(
            slippagePercentage
        );

        // Prepare the token input data for the swap
        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(config.token),
            netTokenIn: _amount,
            tokenMintSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });

        // Execute the swap using Pendle's router
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
     * @notice Redeems Principal Tokens (PT) for underlying tokens
     * @param amount Amount of underlying tokens to redeem
     * @dev This function calculates the PT amount to redeem based on the current exchange rate and slippage,
     *      then performs the swap using Pendle's router
     */
    function _redeemTokenFromPt(uint256 amount) internal {
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));

        // Calculate the amount of PT needed to redeem the requested amount of tokens, accounting for slippage
        uint256 withdrawAmountInPT = _SYtoPT(amount).addPercentage(
            slippagePercentage
        );

        // Use the lesser of the calculated amount or the entire balance
        uint256 finalPtAmount = (withdrawAmountInPT > ptBalance)
            ? ptBalance
            : withdrawAmountInPT;

        // Prepare the token output data for the swap
        TokenOutput memory tokenOutput = TokenOutput({
            tokenOut: address(config.token),
            minTokenOut: amount,
            tokenRedeemSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });

        // Execute the swap using Pendle's router
        IPAllActionV3(router).swapExactPtForToken(
            address(this),
            market,
            finalPtAmount,
            tokenOutput,
            emptyLimitOrderData
        );
    }

    /**
     * @notice Returns the current fixed rate (to be deprecated)
     * @return The maximum uint256 value as a placeholder
     * @dev This function will be deprecated in the future
     */
    function rate() public pure override returns (uint256) {
        return type(uint256).max;
    }

    /**
     * @notice Calculates the total assets held by the Ark
     * @return The total assets in underlying token
     * @dev We decrease the total assets by the allowed slippage to ensure the redeemed amount
     *      is always higher than the requested amount. This provides a conservative estimate
     *      and protects against potential slippage during withdrawals.
     */
    function totalAssets() public view override returns (uint256) {
        return
            _PTtoAsset(_balanceOfPT()).subtractPercentage(slippagePercentage);
    }

    /**
     * @notice Updates the market data (expiry)
     */
    function _updateMarketData() internal {
        marketExpiry = IPMarketV3(market).expiry();
    }

    /**
     * @notice Rolls over to a new market if the current one has expired
     * @dev This function checks if the current market has expired, finds a new market,
     *      redeems all assets, and updates to the new market
     */
    function _rolloverIfNeeded() internal {
        if (block.timestamp < marketExpiry) return;

        address newMarket = this.nextMarket();
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
     * @notice Redeems all PT and SY to underlying tokens
     * @dev This function is called during market rollover to convert all positions back to the underlying asset
     */
    function _redeemAllToUnderlying() internal {
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));
        if (ptBalance > 0) {
            IPAllActionV3(router).redeemPyToSy(
                address(this),
                address(YT),
                ptBalance,
                totalAssets()
            );
        }

        uint256 syBalance = IERC20(SY).balanceOf(address(this));
        if (syBalance > 0) {
            uint256 tokensToRedeem = IStandardizedYield(SY).previewRedeem(
                address(config.token),
                syBalance
            );
            IStandardizedYield(SY).redeem(
                address(this),
                syBalance,
                address(config.token),
                tokensToRedeem,
                false
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
        IERC20(PT).forceApprove(router, type(uint256).max);
    }

    /**
     * @notice Finds the next valid market
     * @return Address of the next market
     */
    function nextMarket() public pure returns (address) {
        // TODO: Implement logic to find the next valid market
        return 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
    }

    /**
     * @notice Converts SY amount to PT amount
     * @param _amount Amount of SY to convert
     * @return Equivalent amount of PT
     */
    function _SYtoPT(uint256 _amount) internal view returns (uint256) {
        uint256 ptToSyRate = PendlePYLpOracle(oracle).getPtToSyRate(
            market,
            oracleDuration
        );
        return (_amount * WAD) / ptToSyRate;
    }

    /**
     * @notice Converts PT amount to SY amount
     * @param _amount Amount of PT to convert
     * @return Equivalent amount of SY
     */
    function _PTtoSY(uint256 _amount) internal view returns (uint256) {
        uint256 ptToSyRate = PendlePYLpOracle(oracle).getPtToSyRate(
            market,
            oracleDuration
        );
        return (_amount * ptToSyRate) / WAD;
    }

    /**
     * @notice Converts PT amount to asset amount
     * @param _amount Amount of PT to convert
     * @return Equivalent amount of asset
     */
    function _PTtoAsset(uint256 _amount) internal view returns (uint256) {
        uint256 syAmount = _PTtoSY(_amount);
        return
            IStandardizedYield(SY).previewRedeem(
                address(config.token),
                syAmount
            );
    }

    /**
     * @notice Returns the balance of PT held by the contract
     * @return Balance of PT
     */
    function _balanceOfPT() internal view returns (uint256) {
        return IERC20(PT).balanceOf(address(this));
    }

    /**
     * @notice Sets the slippage tolerance
     * @param _slippagePercentage New slippage tolerance as a Percentage
     * @dev This function can only be called by the governor
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
     * @param _oracleDuration New oracle duration in seconds
     * @dev This function can only be called by the governor
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
     * @return Total amount of rewards harvested
     * @dev This function redeems rewards from the Pendle market and transfers them to the commander
     */
    function _harvest(
        address,
        bytes calldata
    ) internal override returns (uint256) {
        address[] memory rewardTokens = IPMarketV3(market).getRewardTokens();
        uint256[] memory rewardAmounts = IPMarketV3(market).redeemRewards(
            address(this)
        );
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).safeTransfer(
                config.commander,
                rewardAmounts[i]
            );
            totalRewards += rewardAmounts[i];
        }

        return totalRewards;
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
