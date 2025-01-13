// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./BasePendleArk.sol";

struct PendlePtArkConstructorParams {
    address market;
    address oracle;
    address router;
}

/**
 * @title PendlePTArk
 * @notice Ark contract for managing token supply and yield generation through Pendle Principal Tokens (PT).
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and managing Pendle PT positions.
 */
contract PendlePTArk is BasePendleArk {
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for PendlePTArk
     * @param _pendlePtArkConstructorParams PendlePtArkConstructorParams struct containing initialization parameters
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        PendlePtArkConstructorParams memory _pendlePtArkConstructorParams,
        ArkParams memory _params
    )
        BasePendleArk(
            _pendlePtArkConstructorParams.market,
            _pendlePtArkConstructorParams.oracle,
            _pendlePtArkConstructorParams.router,
            _params
        )
    {}

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev PendlePTArk is always withdrawable
     * @dev TODO:  add logic to check for pause etc
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return totalAssets();
    }

    /**
     * @notice Set up token approvals for Pendle interactions
     */
    function _setupApprovals() internal override {
        config.asset.forceApprove(address(router), Constants.MAX_UINT256);
        IERC20(SY).forceApprove(router, Constants.MAX_UINT256);
        IERC20(PT).forceApprove(router, Constants.MAX_UINT256);
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
    function _depositFleetAssetForArkToken(uint256 _amount) internal override {
        if (block.timestamp >= marketExpiry) {
            revert MarketExpired();
        }
        uint256 minPTout = _assetToArkTokens(_amount).subtractPercentage(
            slippagePercentage
        );

        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(config.asset),
            netTokenIn: _amount,
            tokenMintSy: address(config.asset),
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
     * @notice Redeems PT for underlying tokens before market expiry
     * @param amount Amount of PT to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemFleetAsset(
        uint256 amount,
        uint256 minTokenOut
    ) internal override {
        _redeemFleetAssetFromPtBeforeExpiry(amount, minTokenOut);
    }

    /**
     * @notice Redeems PT for underlying tokens after market expiry
     * @param amount Amount of PT to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     */
    function _redeemFleetAssetPostExpiry(
        uint256 amount,
        uint256 minTokenOut
    ) internal override {
        _redeemMarketAssetFromPtPostExpiry(amount, minTokenOut);
    }

    /**
     * @notice Redeems PT for underlying tokens after market expiry
     * @param ptAmount Amount of PT to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     * @dev Redeems PT to SY using Pendle's router, then redeems SY to underlying token
     * 1. Redeem PT to SY using Pendle's router
     * 2. Redeem SY to underlying token
     * No slippage is applied as the exchange rate is fixed post-expiry
     */
    function _redeemMarketAssetFromPtPostExpiry(
        uint256 ptAmount,
        uint256 minTokenOut
    ) internal {
        if (ptAmount > 0) {
            TokenOutput memory tokenOutput = TokenOutput({
                tokenOut: address(config.asset),
                minTokenOut: minTokenOut,
                tokenRedeemSy: address(config.asset),
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
     * @notice Redeems PT for underlying tokens before market expiry
     * @param ptAmount Amount of PT to redeem
     * @param minTokenOut Minimum amount of underlying tokens to receive
     * @dev Executes the swap using Pendle's router with slippage protection
     * 1. Prepare the token output data for the swap
     * 2. Execute the swap using Pendle's router
     * Slippage protection is applied to ensure the minimum token output
     */
    function _redeemFleetAssetFromPtBeforeExpiry(
        uint256 ptAmount,
        uint256 minTokenOut
    ) internal {
        TokenOutput memory tokenOutput = TokenOutput({
            tokenOut: address(config.asset),
            minTokenOut: minTokenOut,
            tokenRedeemSy: address(config.asset),
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
     */
    function _redeemAllFleetAssetsFromExpiredMarket() internal override {
        uint256 ptBalance = IERC20(PT).balanceOf(address(this));
        _redeemMarketAssetFromPtPostExpiry(ptBalance, ptBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches the PT to Asset rate from the PendlePYLpOracle contract
     * @return The PT to Asset rate as a uint256 value
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

    /**
     * @notice Validates the board data
     * @dev This Ark does not require any validation for board data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev This Ark does not require any validation for disembark data
     * @param /// data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
