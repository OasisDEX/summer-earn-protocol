// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "./BasePendleArk.sol";

/**
 * @title PendlePTArk
 * @notice This contract manages a Pendle Principal Token (PT) strategy within the Ark system
 * @dev Inherits from BasePendleArk and implements PT-specific logic
 */
contract PendlePTArk is BasePendleArk {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /**
     * @notice Constructor for PendlePTArk
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
        config.token.forceApprove(address(router), type(uint256).max);
        IERC20(SY).forceApprove(router, type(uint256).max);
        IERC20(PT).forceApprove(router, type(uint256).max);
    }

    /**
     * @notice Deposits tokens and swaps them for Principal Tokens (PT)
     * @param _amount Amount of tokens to deposit
     * @dev This function performs the following steps:
     * 1. Check if the market has expired, revert if it has
     * 2. Calculate the minimum PT output based on the current exchange rate and slippage
     * 3. Prepare the input token data for the Pendle router
     * 4. Execute the swap using Pendle's router
     *
     * We use slippage protection here to ensure we receive at least the calculated minimum PT tokens.
     * This protects against sudden price movements between our calculation and the actual swap execution.
     */
    function _depositTokenForArkToken(uint256 _amount) internal override {
        if (block.timestamp >= marketExpiry) {
            revert MarketExpired();
        }
        uint256 minPTout = _assetToArkTokens(_amount).subtractPercentage(
            slippagePercentage
        );

        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(config.token),
            netTokenIn: _amount,
            tokenMintSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });

        IPAllActionV3(router).swapExactTokenForPt(
            address(this),
            market,
            minPTout,
            routerParams,
            tokenInput,
            emptyLimitOrderData
        );
    }

    function _redeemTokens(
        uint256 amount,
        uint256 minTokenOut
    ) internal override {
        _redeemTokenFromPtBeforeExpiry(amount, minTokenOut);
    }

    function _redeemTokensPostExpiry(
        uint256 amount,
        uint256 minTokenOut
    ) internal override {
        _redeemTokenFromPtPostExpiry(amount, minTokenOut);
    }

    /**
     * @notice Redeems PT for underlying tokens after market expiry
     * @param ptAmount Amount of PT to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     * @dev This function handles redemption after market expiry:
     * 1. Redeem PT to SY using Pendle's router
     * 2. Redeem SY to underlying token
     * No slippage is applied as the exchange rate is fixed post-expiry
     */
    function _redeemTokenFromPtPostExpiry(
        uint256 ptAmount,
        uint256 minTokenOut
    ) internal {
        if (ptAmount > 0) {
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
     * @notice Redeems PT for underlying tokens before market expiry
     * @param ptAmount Amount of PT to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     * @dev This function handles redemption before market expiry:
     * 1. Prepare the token output data for the swap
     * 2. Execute the swap using Pendle's router
     * Slippage protection is applied to ensure the minimum token output
     */
    function _redeemTokenFromPtBeforeExpiry(
        uint256 ptAmount,
        uint256 minTokenOut
    ) internal {
        TokenOutput memory tokenOutput = TokenOutput({
            tokenOut: address(config.token),
            minTokenOut: minTokenOut,
            tokenRedeemSy: address(config.token),
            pendleSwap: address(0),
            swapData: emptySwap
        });

        IPAllActionV3(router).swapExactPtForToken(
            address(this),
            market,
            ptAmount,
            tokenOutput,
            emptyLimitOrderData
        );
    }

    /**
     * @notice Redeems all PT for underlying tokens after market expiry
     * @dev This function redeems all PT to SY and then redeems SY to the underlying token
     *    check `_redeemTokenFromPtPostExpiry` for more details
     */
    function _redeemAllTokensFromExpiredMarket() internal override {
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));
        _redeemTokenFromPtPostExpiry(ptBalance, ptBalance);
    }

    /**
     * @notice Returns the current fixed rate (to be deprecated)
     * @return The maximum uint256 value as a placeholder
     */
    function rate() public pure override returns (uint256) {
        return type(uint256).max;
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
     * @dev Fetches the PT to SY rate from the PendlePYLpOracle contract.
     * @return The PT to asset rate as a uint256 value.
     */
    function _fetchArkTokenToAssetRate()
        internal
        view
        override
        returns (uint256)
    {
        return
            PendlePYLpOracle(oracle).getPtToAssetRate(market, oracleDuration);
    }

    /**
     * @notice Returns the balance of PT held by the contract
     * @return Balance of PT
     */
    function _balanceOfArkTokens() internal view override returns (uint256) {
        return IERC20(PT).balanceOf(address(this));
    }
}
