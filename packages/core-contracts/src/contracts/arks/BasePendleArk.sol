// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IPendleBaseArk} from "../../interfaces/arks/IPendleBaseArk.sol";
import "../Ark.sol";
import {LimitOrderData, TokenInput, TokenOutput} from "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import {IPAllActionV3} from "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import {IPMarketV3} from "@pendle/core-v2/contracts/interfaces/IPMarketV3.sol";
import {IPPrincipalToken} from "@pendle/core-v2/contracts/interfaces/IPPrincipalToken.sol";
import {IPYieldToken} from "@pendle/core-v2/contracts/interfaces/IPYieldToken.sol";
import {IStandardizedYield} from "@pendle/core-v2/contracts/interfaces/IStandardizedYield.sol";

import {PendlePYLpOracle} from "@pendle/core-v2/contracts/oracles/PendlePYLpOracle.sol";
import {ApproxParams} from "@pendle/core-v2/contracts/router/base/MarketApproxLib.sol";
import {SwapData} from "@pendle/core-v2/contracts/router/swap-aggregator/IPSwapAggregator.sol";

import {Constants} from "@summerfi/constants/Constants.sol";
import {PERCENTAGE_100, Percentage, PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
/**
 * @title BasePendleArk
 * @notice Base contract for Pendle-based Ark strategies
 * @dev This contract contains common functionality for Pendle LP and PT Arks
 */

abstract contract BasePendleArk is Ark, IPendleBaseArk {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum allowed slippage percentage
    Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
    /// @notice Minimum allowed oracle duration
    uint256 public constant MIN_ORACLE_DURATION = 15 minutes;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the current Pendle market
    address public market;
    /// @notice Address of the next Pendle market
    address public nextMarket;
    /// @notice Address of the Pendle router
    address public immutable router;
    /// @notice Address of the Pendle oracle
    address public immutable oracle;
    /// @notice Duration for the oracle to use when fetching rates
    uint32 public oracleDuration;
    /// @notice Standardized Yield token associated with the market
    IStandardizedYield public SY;
    /// @notice Principal Token associated with the market
    IPPrincipalToken public PT;
    /// @notice Yield Token associated with the market
    IPYieldToken public YT;
    /// @notice Slippage tolerance for operations
    Percentage public slippagePercentage;
    /// @notice Expiry timestamp of the current market
    uint256 public marketExpiry;
    /// @notice Parameters for the Pendle router
    ApproxParams public routerParams;
    /// @notice Empty limit order data for Pendle operations
    LimitOrderData emptyLimitOrderData;
    /// @notice Empty swap data for Pendle operations
    SwapData public emptySwap;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for BasePendleArk
     * @param _market Address of the Pendle market
     * @param _oracle Address of the Pendle oracle
     * @param _router Address of the Pendle router
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _market,
        address _oracle,
        address _router,
        ArkParams memory _params
    ) Ark(_params) {
        router = _router;
        oracle = _oracle;
        oracleDuration = 30 minutes;
        slippagePercentage = PercentageUtils.fromFraction(5, 1000); // 0.5% default
        _setupRouterParams();
        _updateMarketAndTokens(_market);
        _updateMarketData();
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
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits assets into the Ark
     * @dev Rolls over to a new market if needed, then deposits tokens for Ark-specific tokens
     * @param amount Amount of assets to deposit
     */
    function _board(uint256 amount, bytes calldata) internal virtual override {
        _rolloverIfNeeded();
        _depositFleetAssetForArkToken(amount);
    }

    /**
     * @dev This function handles redemption differently based on whether the market has expired:
     * 1. If the market has expired:
     *    - Use a 1:1 exchange ratio between PT / LP and asset (no slippage)
     *    - Call _redeemFleetAssetPostExpiry
     * 2. If the market has not expired:
     *    - Calculate PT / LP amount needed, accounting for slippage
     *    - Call _redeemFleetAsset
     *
     * The slippage is applied differently in each case to protect the user from unfavorable price movements.
     */
    function _disembark(
        uint256 amount,
        bytes calldata
    ) internal virtual override {
        _rolloverIfNeeded();
        if (block.timestamp >= marketExpiry) {
            _redeemFleetAssetPostExpiry(amount, amount);
        } else {
            uint256 arkTokenBalance = _balanceOfArkTokens();
            uint256 withdrawAmountInArkTokens = _assetToArkTokens(amount)
                .addPercentage(slippagePercentage);
            uint256 finalAmount = (withdrawAmountInArkTokens > arkTokenBalance)
                ? arkTokenBalance
                : withdrawAmountInArkTokens;
            _redeemFleetAsset(finalAmount, amount);
        }
    }

    /**
     * @notice Harvests rewards from the market
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
     * @notice Internal function to set up router parameters
     */
    function _setupRouterParams() internal {
        routerParams.guessMax = Constants.MAX_UINT256;
        routerParams.maxIteration = 256;
        routerParams.eps = 1e15; // 0.1% precision
    }

    /**
     * @notice Updates the market data (expiry)
     */
    function _updateMarketData() internal {
        marketExpiry = IPMarketV3(market).expiry();
    }

    /**
     * @notice Updates market and token addresses, and sets up new approvals
     * @param newMarket Address of the new market
     */
    function _updateMarketAndTokens(address newMarket) internal {
        market = newMarket;
        (SY, PT, YT) = IPMarketV3(newMarket).readTokens();
        if (
            !IStandardizedYield(SY).isValidTokenIn(address(config.asset)) ||
            !IStandardizedYield(SY).isValidTokenOut(address(config.asset))
        ) {
            revert InvalidAssetForSY();
        }
        _setupApprovals();
        _updateMarketData();
    }

    /**
     * @notice Rolls over to a new market if the current one has expired
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
        _redeemAllFleetAssetsFromExpiredMarket();
        _updateMarketAndTokens(newMarket);

        emit MarketRolledOver(newMarket);
    }

    /**
     * @notice Converts asset amount to Ark-specific tokens (PT or LP)
     * @param amount Amount of asset
     * @return Equivalent amount of Ark-specific tokens
     */
    function _assetToArkTokens(uint256 amount) internal view returns (uint256) {
        return (amount * Constants.WAD) / _fetchArkTokenToAssetRate();
    }

    /**
     * @notice Converts Ark-specific tokens (PT or LP) to asset amount
     * @param amount Amount of Ark-specific tokens
     * @return Equivalent amount of asset
     */
    function _arkTokensToAsset(uint256 amount) internal view returns (uint256) {
        return (amount * _fetchArkTokenToAssetRate()) / Constants.WAD;
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

    /*//////////////////////////////////////////////////////////////
                        ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Abstract method to redeem tokens from the Ark from active market
     * @param amount Amount of Ark-specific tokens to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemFleetAsset(
        uint256 amount,
        uint256 minTokenOut
    ) internal virtual;

    /**
     * @notice Abstract method to redeem tokens after market expiry
     * @param amount Amount of Ark-specific tokens to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemFleetAssetPostExpiry(
        uint256 amount,
        uint256 minTokenOut
    ) internal virtual;

    /**
     * @notice Abstract method to deposit tokens for Ark-specific tokens
     * @param amount Amount of underlying tokens to deposit
     */
    function _depositFleetAssetForArkToken(uint256 amount) internal virtual;

    /**
     * @notice Sets up token approvals
     */
    function _setupApprovals() internal virtual;

    /**
     * @notice Set the next market
     * @param _nextMarket Address of the next market
     */
    function setNextMarket(address _nextMarket) public onlyGovernor {
        nextMarket = _nextMarket;
    }

    /**
     * @notice Redeems all tokens from the current position
     */
    function _redeemAllFleetAssetsFromExpiredMarket() internal virtual;

    /**
     * @notice Abstract method to get the balance of Ark-specific tokens
     * @return Balance of Ark-specific tokens
     */
    function _balanceOfArkTokens() internal view virtual returns (uint256);

    /**
     * @notice Fetches the current exchange rate between Ark-specific tokens and assets
     * @return Current exchange rate
     */
    function _fetchArkTokenToAssetRate()
        internal
        view
        virtual
        returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
            (block.timestamp >= marketExpiry)
                ? _arkTokensToAsset(_balanceOfArkTokens())
                : _arkTokensToAsset(_balanceOfArkTokens()).subtractPercentage(
                    slippagePercentage
                );
    }
}
