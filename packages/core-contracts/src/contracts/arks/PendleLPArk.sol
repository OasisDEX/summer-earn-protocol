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

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Deposits tokens for LP
     * @param _amount Amount of tokens to deposit
     * @dev Checks for market expiry, calculates minimum LP output with slippage, and adds liquidity
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
    function _depositTokenForArkToken(uint256 _amount) internal override {
        if (block.timestamp >= marketExpiry) {
            revert MarketExpired();
        }
        uint256 minLpOut = _assetToArkTokens(_amount).subtractPercentage(
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
     * @notice Redeems LP tokens for underlying assets
     * @param amount Amount of LP tokens to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemTokens(
        uint256 amount,
        uint256 minTokenOut
    ) internal override {
        _removeLiquidity(amount, minTokenOut);
    }

    /**
     * @notice Redeems LP tokens for underlying assets after market expiry
     * @param amount Amount of assets to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemTokensPostExpiry(
        uint256 amount,
        uint256 minTokenOut
    ) internal override {
        uint256 lpAmount = _assetToArkTokens(amount);
        _removeLiquidity(lpAmount, minTokenOut);
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
     * @notice Redeems all LP tokens to underlying tokens
     */
    function _redeemAllTokensFromExpiredMarket() internal override {
        uint256 lpBalance = _balanceOfArkTokens();
        uint256 expectedTokenOut = _arkTokensToAsset(lpBalance);

        if (lpBalance > 0) {
            _removeLiquidity(lpBalance, expectedTokenOut);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Finds the next valid market
     * @return Address of the next market
     * @dev TODO: Implement logic to find the next valid market
     */
    function nextMarket() public pure override returns (address) {
        return 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A;
    }

    /**
     * @notice Fetches the LP to Asset rate from the PendlePYLpOracle contract
     * @return The LP to Asset rate
     */
    function _fetchArkTokenToAssetRate()
        internal
        view
        override
        returns (uint256)
    {
        return
            PendlePYLpOracle(oracle).getLpToAssetRate(market, oracleDuration);
    }

    /**
     * @notice Returns the balance of LP tokens held by the contract
     * @return Balance of LP tokens
     */
    function _balanceOfArkTokens() internal view override returns (uint256) {
        return IERC20(market).balanceOf(address(this));
    }
}
