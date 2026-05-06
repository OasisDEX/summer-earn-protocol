// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ark} from "../Ark.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {ISuperstateSubscribe} from "../../interfaces/superstate/ISuperstateSubscribe.sol";
import {ISuperstateRedeem} from "../../interfaces/superstate/ISuperstateRedeem.sol";
import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";
import {ISuperstateToken, SupportedStablecoin} from "../../interfaces/superstate/ISuperstateToken.sol";

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
 *   This Ark is strictly for synchronous subscriptions using the `subscribe` function and the
 *   `RedemptionIdle` contract for instant liquidity on redemptions.
 */
contract SuperstateSubscribeArk is Ark {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using PriceUtils for Price;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidShareTokenAddress();
    error InvalidSubscribeAddress();
    error InvalidRedeemAddress();
    error InvalidOracleAddress();
    error UnsupportedStablecoin();
    error OraclePriceNotPositive();
    error StaleOraclePrice();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionExecuted(uint256 usdcAmount, address target);
    event RedemptionExecuted(uint256 shareAmount, address target);

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Superstate fund token contract (USTB)
    IERC20Metadata public immutable shareToken;

    /// @notice The Superstate Subscribe contract (usually the token proxy itself)
    ISuperstateSubscribe public immutable superstateSubscribe;

    /// @notice The Superstate Redeem contract (RedemptionIdle contract)
    ISuperstateRedeem public immutable superstateRedeem;

    /// @notice Superstate/Chainlink price feed: price of 1 Superstate share denominated in USDC
    AggregatorV3Interface public immutable oracle;

    uint8 public immutable oracleDecimals;
    uint8 public immutable assetDecimals;
    uint8 public immutable shareDecimals;
    uint256 public immutable ONE_ASSET;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _shareToken,
        address _superstateSubscribe,
        address _superstateRedeem,
        address _oracle,
        ArkParams memory _params
    ) Ark(_params) {
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (_superstateSubscribe == address(0))
            revert InvalidSubscribeAddress();
        if (_superstateRedeem == address(0)) revert InvalidRedeemAddress();
        if (_oracle == address(0)) revert InvalidOracleAddress();

        shareToken = IERC20Metadata(_shareToken);
        superstateSubscribe = ISuperstateSubscribe(_superstateSubscribe);
        superstateRedeem = ISuperstateRedeem(_superstateRedeem);
        oracle = AggregatorV3Interface(_oracle);

        SupportedStablecoin memory info = ISuperstateToken(_superstateSubscribe)
            .supportedStablecoins(address(_params.asset));
        if (info.sweepDestination == address(0)) {
            revert UnsupportedStablecoin();
        }

        oracleDecimals = AggregatorV3Interface(_oracle).decimals();
        shareDecimals = IERC20Metadata(_shareToken).decimals();
        assetDecimals = IERC20Metadata(_params.asset).decimals();
        ONE_ASSET = 10 ** assetDecimals;
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256 assets) {
        uint256 currentShares = shareToken.balanceOf(address(this));
        assets = _sharesToAssets(currentShares);
    }

    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _board(uint256 amount, bytes calldata) internal override {
        IERC20Metadata(address(config.asset)).forceApprove(
            address(superstateSubscribe),
            amount
        );
        superstateSubscribe.subscribe(
            address(this),
            amount,
            address(config.asset)
        );

        emit SubscriptionExecuted(amount, address(superstateSubscribe));
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        uint256 sharesToRedeem = _assetsToShares(amount);

        shareToken.forceApprove(address(superstateRedeem), sharesToRedeem);
        superstateRedeem.redeem(sharesToRedeem, address(this));

        emit RedemptionExecuted(sharesToRedeem, address(superstateRedeem));
    }

    function _validateBoardData(bytes calldata) internal override {}
    function _validateDisembarkData(bytes calldata) internal override {}

    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return totalAssets();
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
        (, int256 answer, , uint256 updatedAt, ) = oracle.latestRoundData();
        if (answer <= 0) revert OraclePriceNotPositive();

        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT_TIMEOUT) {
            revert StaleOraclePrice();
        }

        return
            toPriceFromOraclePrice(
                10 ** shareDecimals,
                answer,
                oracleDecimals,
                assetDecimals
            );
    }
}
