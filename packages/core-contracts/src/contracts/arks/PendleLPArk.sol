// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./BasePendleArk.sol";

/**
 * @title PendleLPArk
 * @notice This contract manages a Pendle LP token strategy within the Ark system
 * @dev Inherits from BasePendleArk and implements LP-specific logic
 */
contract PendleLPArk is BasePendleArk {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /**
     * @notice Constructor for PendleLPArk
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
    ) BasePendleArk(_market, _oracle, _router, _params) {}

    /**
     * @notice Set up token approvals for Pendle interactions
     */
    function _setupApprovals() internal override {
        config.token.forceApprove(address(SY), type(uint256).max);
        config.token.forceApprove(router, type(uint256).max);
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
            uint256 lpBalance = _balanceOfLP();

            uint256 withdrawAmountInLp = _assetToLP(amount).addPercentage(
                slippagePercentage
            );
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
     * @notice Redeems all LP to underlying tokens
     */
    function _redeemAllTokensFromExpiredMarket() internal override {
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
        // TODO: rate will be deprecated in the future
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
     * @notice Finds the next valid market
     * @return Address of the next market
     */
    function nextMarket() public pure override returns (address) {
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
}
