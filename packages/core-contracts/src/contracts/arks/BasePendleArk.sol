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
import {MarketExpired, InvalidNextMarket, OracleDurationTooLow, SlippagePercentageTooHigh, InvalidAssetForSY} from "../../errors/arks/PendleArkErrors.sol";
import {IPendleArkEvents} from "../../events/arks/IPendleArkEvents.sol";

/**
 * @title BasePendleArk
 * @notice Base contract for Pendle-based Ark strategies
 * @dev This contract contains common functionality for Pendle LP and PT Arks
 */
abstract contract BasePendleArk is Ark, IPendleArkEvents {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    // Constants
    Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
    uint256 public constant MIN_ORACLE_DURATION = 15 minutes;

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

    function _board(uint256 amount) internal override {
        _rolloverIfNeeded();
        _depositTokenForArkToken(amount);
    }

    /**
     * @dev This function handles redemption differently based on whether the market has expired:
     * 1. If the market has expired:
     *    - Use a 1:1 exchange ratio between PT / LP and asset (no slippage)
     *    - Call _redeemTokensPostExpiry
     * 2. If the market has not expired:
     *    - Calculate PT / LP amount needed, accounting for slippage
     *    - Call _redeemTokens
     *
     * The slippage is applied differently in each case to protect the user from unfavorable price movements.
     */
    function _disembark(uint256 amount) internal override {
        _rolloverIfNeeded();
        if (block.timestamp >= marketExpiry) {
            _redeemTokensPostExpiry(amount, amount);
        } else {
            uint256 arkTokenBalance = _balanceOfArkTokens();
            uint256 withdrawAmountInArkTokens = _assetToArkTokens(amount)
                .addPercentage(slippagePercentage);
            uint256 finalAmount = (withdrawAmountInArkTokens > arkTokenBalance)
                ? arkTokenBalance
                : withdrawAmountInArkTokens;
            _redeemTokens(finalAmount, amount);
        }
    }

    /**
     * @notice Abstract method to redeem tokens from the Ark ifrom active market
     * @param amount Amount of underlying tokens to redeem
     */
    function _redeemTokens(
        uint256 amount,
        uint256 minTokenOut
    ) internal virtual;

    /**
     * @notice Abstract method to redeem tokens after market expiry
     * @param amount Amount to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemTokensPostExpiry(
        uint256 amount,
        uint256 minTokenOut
    ) internal virtual;
    function _depositTokenForArkToken(uint256 amount) internal virtual;
    /**
     * @notice Internal function to set up router parameters
     */
    function _setupRouterParams() internal {
        routerParams.guessMax = type(uint256).max;
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
            !IStandardizedYield(SY).isValidTokenIn(address(config.token)) ||
            !IStandardizedYield(SY).isValidTokenOut(address(config.token))
        ) {
            revert InvalidAssetForSY();
        }
        _setupApprovals();
        _updateMarketData();
    }

    /**
     * @notice Sets up token approvals
     */
    function _setupApprovals() internal virtual;

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
        _redeemAllTokensFromExpiredMarket();
        _updateMarketAndTokens(newMarket);

        emit MarketRolledOver(newMarket);
    }

    /**
     * @notice Finds the next valid market
     * @return Address of the next market
     */
    function nextMarket() public view virtual returns (address);

    /**
     * @notice Redeems all tokens from the current position
     */
    function _redeemAllTokensFromExpiredMarket() internal virtual;

    /**
     * @notice Abstract method to get the balance of Ark-specific tokens
     * @return Balance of Ark-specific tokens
     */
    function _balanceOfArkTokens() internal view virtual returns (uint256);

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

    /**
     * @notice Method to convert asset amount to Ark-specific tokens (PT or LP)
     * @param amount Amount of asset
     * @return Equivalent amount of Ark-specific tokens
     * This is an approximation and may not be exact due to rounding errors.
     * Since the oracle is TWAP based, the rate lag is expected.
     */
    function _assetToArkTokens(uint256 amount) internal view returns (uint256) {
        return (amount * WAD) / _fetchArkTokenToAssetRate();
    }
    /**
     * @notice Method to convert Ark-specific tokens (PT or LP) to asset amount
     * @param amount Amount of Ark-specific tokens
     * @return Equivalent amount of asset
     * Since the oracle is TWAP based, the rate lag is expected.
     */
    function _arkTokensToAsset(uint256 amount) internal view returns (uint256) {
        return (amount * _fetchArkTokenToAssetRate()) / WAD;
    }
    function _fetchArkTokenToAssetRate()
        internal
        view
        virtual
        returns (uint256);

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

    /**
     * @notice Harvests rewards from the market
     * @return totalRewards amount of rewards harvested
     * TODO: Modify `RAFT` to support multiple token harvest and harvest without input token address
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
        (
            bool increaseCardinalityRequired,
            ,
            bool oldestObservationSatisfied
        ) = PendlePYLpOracle(oracle).getOracleState(_market, oracleDuration);
        // The oracle is ready if:
        // 1. No increase in cardinality is required (increaseCardinalityRequired is false)
        // 2. The oldest observation is satisfied (oldestObservationSatisfied is true)

        return !increaseCardinalityRequired && oldestObservationSatisfied;
    }
}
