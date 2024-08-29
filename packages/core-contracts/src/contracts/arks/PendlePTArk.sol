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
     * @dev This function performs the following steps:
     * 1. Check if the market has expired, revert if it has
     * 2. Calculate the minimum PT output based on the current exchange rate and slippage
     * 3. Prepare the input token data for the Pendle router
     * 4. Execute the swap using Pendle's router
     *
     * We use slippage protection here to ensure we receive at least the calculated minimum PT tokens.
     * This protects against sudden price movements between our calculation and the actual swap execution.
     */
    function _depositTokenForPt(uint256 _amount) internal {
        if (block.timestamp >= marketExpiry) {
            revert MarketExpired();
        }
        uint256 minPTout = _SYtoPT(_amount).subtractPercentage(
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

    /**
     * @notice Redeems Principal Tokens (PT) for underlying tokens
     * @param amount Amount of underlying tokens to redeem
     * @dev This function handles redemption differently based on whether the market has expired:
     * 1. If the market has expired:
     *    - Use a 1:1 exchange ratio between PT and asset (no slippage)
     *    - Call _redeemTokenFromPtPostExpiry
     * 2. If the market has not expired:
     *    - Calculate PT amount needed, accounting for slippage
     *    - Call _redeemTokenFromPtBeforeExpiry
     *
     * The slippage is applied differently in each case to protect the user from unfavorable price movements.
     */
    function _redeemTokenFromPt(uint256 amount) internal {
        if (block.timestamp >= marketExpiry) {
            // If the market is expired, we redeem all PT and SY to underlying tokens
            // The exchange ratio between PT and asset is 1:1 with no slippage
            uint256 ptAmount = amount;
            uint256 minTokenOut = amount;
            _redeemTokenFromPtPostExpiry(ptAmount, minTokenOut);
        } else {
            uint256 ptBalance = IERC20(PT).balanceOf(address(this));

            // Calculate the amount of PT needed to redeem the requested amount of tokens, accounting for slippage
            uint256 withdrawAmountInPT = _SYtoPT(amount).addPercentage(
                slippagePercentage
            );
            // Use the lesser of the calculated amount or the entire balance /// TODO: check that thoroughly if it can be explited
            uint256 finalPtAmount = (withdrawAmountInPT > ptBalance)
                ? ptBalance
                : withdrawAmountInPT;
            _redeemTokenFromPtBeforeExpiry(finalPtAmount, amount);
        }
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
     * @notice Calculates the total assets held by the Ark
     * @return The total assets in underlying token
     * @dev We handle this differently based on whether the market has expired:
     * 1. If the market has expired: return the exact PT balance (1:1 ratio)
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
                ? _PTtoAsset(_balanceOfPT())
                : _PTtoAsset(_balanceOfPT()).subtractPercentage(
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
     * @notice Converts SY amount to PT amount
     * @param _amount Amount of SY to convert
     * @return Equivalent amount of PT
     */
    function _SYtoPT(uint256 _amount) internal view returns (uint256) {
        return (_amount * WAD) / fetchPtToSyRate();
    }

    /**
     * @notice Converts PT amount to SY amount
     * @param _amount Amount of PT to convert
     * @return Equivalent amount of SY
     */
    function _PTtoSY(uint256 _amount) internal view returns (uint256) {
        return (_amount * fetchPtToSyRate()) / WAD;
    }

    /**
     * @dev Fetches the PT to SY rate from the PendlePYLpOracle contract.
     * @return The PT to asset rate as a uint256 value.
     */
    function fetchPtToSyRate() internal view returns (uint256) {
        return PendlePYLpOracle(oracle).getPtToSyRate(market, oracleDuration);
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
}
