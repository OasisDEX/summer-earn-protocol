// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IStandardizedYield} from "../../interfaces/pendle/IStandardizedYield.sol";
import {IPendleOracle} from "../../interfaces/pendle/IPendleOracle.sol";
import {IPendleRouter} from "../../interfaces/pendle/IPendleRouter.sol";
import {IPendleMarket} from "../../interfaces/pendle/IPendleMarket.sol";
import {console} from "forge-std/console.sol";
/// @title PendlePTArk
/// @notice This contract manages a Pendle Principal Token (PT) strategy within the Ark system
/// @dev Inherits from Ark and implements Pendle-specific logic
contract PendlePTArk is Ark {
    using SafeERC20 for IERC20;

    // Constants
    uint256 private constant WAD = 1e18;
    uint256 private constant MAX_BPS = 10_000;
    uint256 private constant SECONDS_IN_YEAR = 365 days;
    uint256 private constant MIN_ORACLE_DURATION = 900; // 15 minutes
    address private constant PENDLE_ROUTER =
        0x888888888889758F76e7103c6CbF23ABbF58F946;

    // State variables
    address public market;
    address public immutable oracle;
    uint32 public oracleDuration;
    address public SY;
    address public PT;
    address public YT;
    uint256 public slippageBPS;
    uint256 public fixedRate;
    uint256 public marketExpiry;
    IPendleRouter.ApproxParams public routerParams;
    IPendleRouter.LimitOrderData emptyLimitOrderData;
    // Events
    event MarketRolledOver(address indexed newMarket);
    event SlippageUpdated(uint256 newSlippageBPS);
    event OracleDurationUpdated(uint32 newOracleDuration);

    /// @notice Constructor for PendlePTArk
    /// @param _asset Address of the underlying asset
    /// @param _market Address of the Pendle market
    /// @param _oracle Address of the Pendle oracle
    /// @param _params ArkParams struct containing initialization parameters
    constructor(
        address _asset,
        address _market,
        address _oracle,
        ArkParams memory _params
    ) Ark(_params) {
        market = _market;
        oracle = _oracle;
        oracleDuration = 1800; // half hour default
        slippageBPS = 50; // 0.5% default slippage

        (SY, PT, YT) = IPendleMarket(_market).readTokens();
        require(
            IStandardizedYield(SY).isValidTokenIn(_asset) &&
                IStandardizedYield(SY).isValidTokenOut(_asset),
            "Invalid asset for SY"
        );

        _setupRouterParams();
        _setupApprovals(_asset);
        _updateMarketData();
    }

    /// @notice Internal function to set up router parameters
    function _setupRouterParams() private {
        routerParams.guessMax = type(uint256).max;
        routerParams.maxIteration = 256;
        routerParams.eps = 1e15; // 0.1% precision
    }

    /// @notice Internal function to set up token approvals
    /// @param _asset Address of the underlying asset
    function _setupApprovals(address _asset) private {
        IERC20(_asset).forceApprove(SY, type(uint256).max);
        IERC20(SY).forceApprove(PENDLE_ROUTER, type(uint256).max);
        IERC20(PT).forceApprove(PENDLE_ROUTER, type(uint256).max);
    }

    /// @notice Boards (deposits) assets into the Ark
    /// @param amount Amount of assets to board
    function _board(uint256 amount) internal override {
        _rolloverIfNeeded();
        _depositTokenForPt(amount);
    }

    /// @notice Disembarks (withdraws) assets from the Ark
    /// @param amount Amount of assets to disembark
    function _disembark(uint256 amount) internal override {
        _rolloverIfNeeded();
        _redeemTokenFromPt(amount);
    }

    /// @notice Deposits tokens for PT
    /// @param _amount Amount of tokens to deposit
    function _depositTokenForPt(uint256 _amount) internal {
        uint256 sharesOut = IStandardizedYield(SY).previewDeposit(
            address(config.token),
            _amount
        );
        uint256 syAmount = IStandardizedYield(SY).deposit(
            address(this),
            address(config.token),
            _amount,
            sharesOut
        );

        uint256 minPTout = (_SYtoPT(syAmount) * (MAX_BPS - slippageBPS)) /
            MAX_BPS;

        IPendleRouter(PENDLE_ROUTER).swapExactSyForPt(
            address(this),
            market,
            syAmount,
            minPTout,
            routerParams,
            emptyLimitOrderData
        );
    }

    /// @notice Redeems PT for tokens
    /// @param amount Amount of PT to redeem
    function _redeemTokenFromPt(uint256 amount) internal {
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));
        uint256 withdrawAmountInPT = (_SYtoPT(amount) *
            (MAX_BPS + slippageBPS)) / MAX_BPS;

        amount = (withdrawAmountInPT > ptBalance)
            ? ptBalance
            : withdrawAmountInPT;

        uint256 expectedSyOut = _PTtoSY(amount);
        uint256 minSyOut = (expectedSyOut * (MAX_BPS - slippageBPS)) / MAX_BPS;

        (uint256 syAmount, ) = IPendleRouter(PENDLE_ROUTER).swapExactPtForSy(
            address(this),
            market,
            amount,
            minSyOut,
            emptyLimitOrderData
        );
        uint256 expectedTokenOut = IStandardizedYield(SY).previewRedeem(
            address(config.token),
            syAmount
        );
        uint256 minTokenOut = (expectedTokenOut * (MAX_BPS - slippageBPS)) /
            MAX_BPS;

        IStandardizedYield(SY).redeem(
            address(this),
            syAmount,
            address(config.token),
            minTokenOut,
            false
        );
    }

    /// @notice Calculates the fixed rate for the current market
    /// @return The calculated fixed rate
    function _calculateFixedRate() internal view returns (uint256) {
        if (block.timestamp >= marketExpiry) return 0;
        IPendleMarket.MarketState memory state = IPendleMarket(market)
            .readState(PENDLE_ROUTER);
        return aprToApy(state.lastLnImpliedRate);
    }

    /// @notice Converts APR to APY
    /// @param apr The APR to convert (in WAD format)
    /// @return The calculated APY (in WAD format)
    function aprToApy(uint256 apr) public pure returns (uint256) {
        uint256 x = apr;
        uint256 result = WAD; // 1 in WAD format

        // x
        result += x;

        // x^2 / 2!
        x = (x * apr) / WAD;
        result += x / 2;

        // x^3 / 3!
        x = (x * apr) / WAD;
        result += x / 6;

        // x^4 / 4!
        x = (x * apr) / WAD;
        result += x / 24;

        // x^5 / 5!
        x = (x * apr) / WAD;
        result += x / 120;

        // Subtract WAD to get (e^apr - 1)
        return result - WAD;
    }

    /// @notice Returns the current fixed rate
    /// @return The current fixed rate
    function rate() public view override returns (uint256) {
        return fixedRate;
    }

    /// @notice Returns the total assets held by the Ark
    /// @return The total assets in underlying token
    function totalAssets() public view override returns (uint256) {
        return (_PTtoAsset(_balanceOfPT()) * (MAX_BPS - slippageBPS)) / MAX_BPS;
    }

    /// @notice Updates the market data (expiry and fixed rate)
    function _updateMarketData() internal {
        marketExpiry = IPendleMarket(market).expiry();
        fixedRate = _calculateFixedRate();
    }

    /// @notice Rolls over to a new market if the current one has expired
    function _rolloverIfNeeded() internal {
        if (block.timestamp < marketExpiry) return;

        address newMarket = _findNextMarket();
        require(newMarket != address(0), "No valid next market");

        _redeemAllToUnderlying();
        require(!(_isOracleReady(newMarket)), "Oracle not ready");

        _updateMarketAndTokens(newMarket);
        _updateMarketData();

        emit MarketRolledOver(newMarket);
    }

    /// @notice Redeems all PT and SY to underlying tokens
    function _redeemAllToUnderlying() internal {
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));
        if (ptBalance > 0) {
            IPendleRouter(PENDLE_ROUTER).redeemPyToSy(
                address(this),
                YT,
                ptBalance,
                0
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

    /// @notice Updates market and token addresses, and sets up new approvals
    /// @param newMarket Address of the new market
    function _updateMarketAndTokens(address newMarket) internal {
        market = newMarket;
        (SY, PT, YT) = IPendleMarket(newMarket).readTokens();

        IERC20(config.token).forceApprove(SY, type(uint256).max);
        IERC20(SY).forceApprove(newMarket, type(uint256).max);
        IERC20(SY).forceApprove(PENDLE_ROUTER, type(uint256).max);
        IERC20(PT).forceApprove(PENDLE_ROUTER, type(uint256).max);
    }

    /// @notice Finds the next valid market
    /// @return Address of the next market
    function _findNextMarket() internal pure returns (address) {
        // TODO: Implement logic to find the next valid market
        return 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
    }

    /// @notice Converts SY amount to PT amount
    /// @param _amount Amount of SY to convert
    /// @return Equivalent amount of PT
    function _SYtoPT(uint256 _amount) internal view returns (uint256) {
        uint256 ptToSyRate = IPendleOracle(oracle).getPtToSyRate(
            market,
            oracleDuration
        );
        return (_amount * WAD) / ptToSyRate;
    }

    /// @notice Converts PT amount to SY amount
    /// @param _amount Amount of PT to convert
    /// @return Equivalent amount of SY
    function _PTtoSY(uint256 _amount) internal view returns (uint256) {
        uint256 ptToSyRate = IPendleOracle(oracle).getPtToSyRate(
            market,
            oracleDuration
        );
        return (_amount * ptToSyRate) / WAD;
    }

    /// @notice Converts PT amount to asset amount
    /// @param _amount Amount of PT to convert
    /// @return Equivalent amount of asset
    function _PTtoAsset(uint256 _amount) internal view returns (uint256) {
        uint256 syAmount = _PTtoSY(_amount);
        return
            IStandardizedYield(SY).previewRedeem(
                address(config.token),
                syAmount
            );
    }

    /// @notice Returns the balance of PT held by the contract
    /// @return Balance of PT
    function _balanceOfPT() internal view returns (uint256) {
        return IERC20(PT).balanceOf(address(this));
    }

    /// @notice Sets the slippage tolerance in basis points
    /// @param _slippageBPS New slippage tolerance
    function setSlippageBPS(uint256 _slippageBPS) external onlyGovernor {
        require(_slippageBPS <= MAX_BPS, "Invalid slippage");
        slippageBPS = _slippageBPS;
        emit SlippageUpdated(_slippageBPS);
    }

    /// @notice Sets the oracle duration
    /// @param _oracleDuration New oracle duration
    function setOracleDuration(uint32 _oracleDuration) external onlyGovernor {
        require(_oracleDuration >= MIN_ORACLE_DURATION, "Duration too low");
        oracleDuration = _oracleDuration;
        emit OracleDurationUpdated(_oracleDuration);
    }

    /// @notice Harvests rewards from the market
    /// @return Total amount of rewards harvested
    function _harvest(
        address,
        bytes calldata
    ) internal override returns (uint256) {
        address[] memory rewardTokens = IPendleMarket(market).getRewardTokens();
        uint256[] memory rewardAmounts = IPendleMarket(market).redeemRewards(
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

    // https://docs.pendle.finance/Developers/Oracles/HowToIntegratePtAndLpOracle#third-initialize-the-oracle
    function _isOracleReady(address _market) internal view returns (bool) {
        (
            bool increaseCardinalityRequired,
            ,
            bool oldestObservationSatisfied
        ) = IPendleOracle(oracle).getOracleState(_market, oracleDuration);
        return (increaseCardinalityRequired || !oldestObservationSatisfied);
    }

    error OracleNotReady();
}
