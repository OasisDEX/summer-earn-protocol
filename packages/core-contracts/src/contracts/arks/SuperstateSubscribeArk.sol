// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ark} from "../Ark.sol";
import {ArkWithWithdrawalRequest} from "../ArkWithWithdrawalRequest.sol";
import {IArkWithWithdrawalRequest} from "../../interfaces/IArkWithWithdrawalRequest.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {ISuperstateToken, SupportedStablecoin} from "../../interfaces/superstate/ISuperstateToken.sol";
import {ISuperstateRedeem} from "../../interfaces/superstate/ISuperstateRedeem.sol";
import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {ISuperstateSubscribeArk} from "../../interfaces/arks/ISuperstateSubscribeArk.sol";

/**
 * @title SuperstateSubscribeArk
 * @notice Integration contract for programmatically interacting with Superstate's Tokenized Funds (like USTB).
 * @dev
 * **Allowlist Requirements:**
 * Superstate funds are regulated securities. The address interacting with the Superstate Subscribe/Redeem
 * contracts (this Ark) MUST be on the Superstate on-chain Allowlist. If not, transaction calls will revert.
 *
 * **Timing Nuances & Settlement:**
 * - USTB (Short Duration US Gov Securities): Processes nearly instantly during US market hours.
 *   This Ark tries synchronous redemption via the `RedemptionIdle` contract first. If that fails
 *   (e.g. market is closed), it falls back to an off-chain async redemption path identical to
 *   SuperstateStandardArk: shares are transferred to the redeem address, and the keeper calls
 *   `sweep()` once USDC arrives.
 */
contract SuperstateSubscribeArk is
    ArkWithWithdrawalRequest,
    ISuperstateSubscribeArk
{
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using PriceUtils for Price;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 24 hours;
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Superstate fund token contract (USTB)
    IERC20Metadata public immutable SHARE_TOKEN;

    /// @notice The Superstate Subscribe contract (usually the token proxy itself)
    ISuperstateToken public immutable SUPERSTATE_SUBSCRIBE;

    /// @notice The Superstate Redeem contract (RedemptionIdle contract)
    ISuperstateRedeem public immutable SUPERSTATE_REDEEM;

    /// @notice Superstate/Chainlink price feed: price of 1 Superstate share denominated in USDC
    AggregatorV3Interface public immutable ORACLE;

    uint8 public immutable ORACLE_DECIMALS;
    uint8 public immutable ASSET_DECIMALS;
    uint8 public immutable SHARE_DECIMALS;
    uint256 public immutable ONE_ASSET;

    /// @notice Expected returning USDC amount equivalent to redeemed shares (handles async fallback)
    uint256 public pendingWithdrawalShares;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySelf() {
        if (_msgSender() != address(this)) revert OnlySelf();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _shareToken,
        address _superstateSubscribe,
        address _superstateRedeem,
        address _oracle,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (_superstateSubscribe == address(0))
            revert InvalidSubscribeAddress();
        if (_superstateRedeem == address(0)) revert InvalidRedeemAddress();
        if (_oracle == address(0)) revert InvalidOracleAddress();

        SHARE_TOKEN = IERC20Metadata(_shareToken);
        SUPERSTATE_SUBSCRIBE = ISuperstateToken(_superstateSubscribe);
        SUPERSTATE_REDEEM = ISuperstateRedeem(_superstateRedeem);

        if (_oracle != SUPERSTATE_SUBSCRIBE.superstateOracle()) {
            revert InvalidOracleAddress();
        }

        ORACLE = AggregatorV3Interface(_oracle);

        SupportedStablecoin memory info = ISuperstateToken(_superstateSubscribe)
            .supportedStablecoins(address(_params.asset));
        if (info.sweepDestination == address(0)) {
            revert UnsupportedStablecoin();
        }

        ORACLE_DECIMALS = AggregatorV3Interface(_oracle).decimals();
        SHARE_DECIMALS = IERC20Metadata(_shareToken).decimals();
        ASSET_DECIMALS = IERC20Metadata(_params.asset).decimals();
        ONE_ASSET = 10 ** ASSET_DECIMALS;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets()
        public
        view
        override(Ark, IArk)
        returns (uint256 assets)
    {
        uint256 totalShares = SHARE_TOKEN.balanceOf(address(this)) +
            pendingWithdrawalShares;
        assets = _sharesToAssets(totalShares);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function assetsInWithdrawalQueue() public view override returns (uint256) {
        return _sharesToAssets(pendingWithdrawalShares);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawalRequestId() external pure override returns (uint256) {
        return 0;
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function isWithdrawalClaimRequired() external pure override returns (bool) {
        return false;
    }

    /**
     * @notice Converts shares to assets.
     */
    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                          KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Explicitly initiates an async redemption. Useful when the keeper wants to bypass
     *         the synchronous attempt and go straight to the off-chain path.
     */
    function requestWithdrawal(uint256 amount) external override onlyKeeper {
        uint256 sharesToRedeem = _assetsToShares(amount);

        pendingWithdrawalShares += sharesToRedeem;
        SHARE_TOKEN.safeTransfer(address(SUPERSTATE_REDEEM), sharesToRedeem);

        emit RedemptionExecuted(sharesToRedeem, address(SUPERSTATE_REDEEM));
        emit WithdrawalRequested(amount, 0);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function claimWithdrawal() external override onlyKeeper {
        // No-op: Superstate asynchronous process delivers USDC directly.
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     */
    function withdrawUsingSwap(
        uint256,
        bytes calldata
    ) external override onlyKeeper nonReentrant {
        // No-op
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _board(uint256 amount, bytes calldata) internal override {
        IERC20Metadata(address(config.asset)).forceApprove(
            address(SUPERSTATE_SUBSCRIBE),
            amount
        );
        SUPERSTATE_SUBSCRIBE.subscribe(
            address(this),
            amount,
            address(config.asset)
        );

        emit SubscriptionExecuted(amount, address(SUPERSTATE_SUBSCRIBE));
    }

    /**
     * @dev Mirrors ERC4626Ark._disembark: full exits use `_directRedeemShares` (exact shares,
     *      avoids rounding issues), partial exits use `_directWithdrawAmount` (asset-denominated).
     *      Both attempt synchronous settlement first; if that reverts (e.g. market closed) the
     *      async off-chain path is taken via `_withdrawShares`.
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // To prevent dust in the ark we check if the amount is equal to the total assets
        // and if there are no pending withdrawals. In that case we redeem all the shares
        // at once.
        if (amount == totalAssets() && assetsInWithdrawalQueue() == 0) {
            uint256 allShares = SHARE_TOKEN.balanceOf(address(this));
            try this._directRedeemShares(allShares) {
                emit RedemptionExecuted(allShares, address(SUPERSTATE_REDEEM));
            } catch {
                _withdrawShares(allShares, amount);
            }
        } else {
            // Otherwise we just withdraw the amount requested
            try this._directWithdrawAmount(amount) {
                uint256 shares = _assetsToShares(amount);
                emit RedemptionExecuted(shares, address(SUPERSTATE_REDEEM));
            } catch {
                _withdrawShares(_assetsToShares(amount), amount);
            }
        }
    }

    /**
     * @dev Synchronous full-exit path: approves and calls `SUPERSTATE_REDEEM.redeem` with an
     *      exact share amount, expecting config.asset to arrive at this address immediately.
     *      Called via `this.` so the revert can be caught by `_disembark`.
     * @param sharesToRedeem The exact number of fund-token shares to redeem.
     */
    function _directRedeemShares(uint256 sharesToRedeem) external onlySelf {
        SHARE_TOKEN.forceApprove(address(SUPERSTATE_REDEEM), sharesToRedeem);
        SUPERSTATE_REDEEM.redeem(sharesToRedeem, address(this));
    }

    /**
     * @dev Synchronous partial-exit path: approves and calls `SUPERSTATE_REDEEM.withdraw` with
     *      an asset-denominated amount, expecting config.asset to arrive at this address immediately.
     *      Called via `this.` so the revert can be caught by `_disembark`.
     * @param amount The asset-denominated amount to withdraw.
     */
    function _directWithdrawAmount(uint256 amount) external onlySelf {
        uint256 shares = _assetsToShares(amount);
        SHARE_TOKEN.forceApprove(address(SUPERSTATE_REDEEM), shares);
        SUPERSTATE_REDEEM.withdraw(address(SHARE_TOKEN), address(this), amount);
    }

    /**
     * @dev Async off-chain path: transfers shares to the redeem contract and increments
     *      `pendingWithdrawalShares`. The keeper must call `sweep()` once USDC arrives.
     * @param sharesToRedeem The number of fund-token shares being sent off-chain.
     * @param amount The asset-denominated amount, emitted in WithdrawalRequested.
     */
    function _withdrawShares(uint256 sharesToRedeem, uint256 amount) internal {
        SHARE_TOKEN.safeTransfer(address(SUPERSTATE_REDEEM), sharesToRedeem);
        pendingWithdrawalShares += sharesToRedeem;

        emit RedemptionExecuted(sharesToRedeem, address(SUPERSTATE_REDEEM));
        emit WithdrawalRequested(amount, 0);
    }

    function _validateBoardData(bytes calldata) internal override {}

    function _validateDisembarkData(bytes calldata) internal override {}

    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        uint256 balanceRedemptionContract = IERC20Metadata(
            address(config.asset)
        ).balanceOf(address(SUPERSTATE_REDEEM));

        uint256 theoreticalWithdrawableAssets = totalAssets() -
            assetsInWithdrawalQueue();

        // Cannot withdraw more than it is available in the redemption contract
        return
            Math.min(balanceRedemptionContract, theoreticalWithdrawableAssets);
    }

    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    /*//////////////////////////////////////////////////////////////
                            ORACLE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.invert().quote(shares);
    }

    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        if (assetAmount == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.quote(assetAmount);
    }

    function _fetchOracleAssetPerSharePrice()
        internal
        view
        returns (Price memory)
    {
        (, int256 answer, , uint256 updatedAt, ) = ORACLE.latestRoundData();
        if (answer <= 0) revert OraclePriceNotPositive();

        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT_TIMEOUT) {
            revert StaleOraclePrice();
        }

        return
            toPriceFromOraclePrice(
                10 ** SHARE_DECIMALS,
                answer,
                ORACLE_DECIMALS,
                ASSET_DECIMALS
            );
    }
}
