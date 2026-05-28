// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ark} from "../Ark.sol";
import {ArkWithWithdrawalRequest} from "../ArkWithWithdrawalRequest.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {IArkWithWithdrawalRequest} from "../../interfaces/IArkWithWithdrawalRequest.sol";
import {IFleetCommander} from "../../interfaces/IFleetCommander.sol";
import {ArkParams} from "../../types/ArkTypes.sol";
import {AggregatorV3Interface} from "../../interfaces/external/Chainlink/AggregatorV3Interface.sol";

import {PERCENTAGE_FACTOR, Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "@summerfi/price-solidity/contracts/PriceUtils.sol";

import {ISuperstateArkErrors} from "../../errors/arks/ISuperstateArkErrors.sol";
import {ISuperstateArkEvents} from "../../events/arks/ISuperstateArkEvents.sol";

/**
 * @title BaseSuperstateArk
 * @notice Shared base for Ark implementations that custody Superstate fund tokens (USTB, USCC).
 * @dev Holds the oracle helpers, share/asset conversion, `pendingWithdrawalShares` accounting,
 *      the keeper-gated `sweep()` (slippage-banded, zeroes the pending counter, forwards USDC
 *      to the buffer ark), and the no-op interface stubs required by `IArkWithWithdrawalRequest`
 *      for Superstate's settlement model.
 *
 *      Subclasses implement the lifecycle-specific pieces: `_board`, `_disembark`,
 *      `_withdrawableTotalAssets`, `totalAssets`, and `requestWithdrawal`.
 */
abstract contract BaseSuperstateArk is
    ArkWithWithdrawalRequest,
    ISuperstateArkErrors,
    ISuperstateArkEvents
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    using PriceUtils for Price;
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Slippage value passed up to ArkWithWithdrawalRequest. Unused — Superstate arks do not perform swaps.
    uint256 public constant DEFAULT_SWAP_SLIPPAGE = 2;
    /// @notice Oracle price is considered stale after this duration.
    uint256 public constant ORACLE_HEARTBEAT_TIMEOUT = 24 hours;
    /// @notice Maximum allowed sweep slippage. Under the Percentage library convention (100% = 100 * 1e18) this equals 0.5%.
    Percentage public constant MAX_SWEEP_SLIPPAGE =
        Percentage.wrap(PERCENTAGE_FACTOR / 2);

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Superstate fund token contract (e.g. USTB or USCC).
    IERC20Metadata public immutable SHARE_TOKEN;
    /// @notice Chainlink-style oracle returning the price of 1 share denominated in the base asset.
    AggregatorV3Interface public immutable ORACLE;
    /// @notice Decimals reported by the oracle.
    uint8 public immutable ORACLE_DECIMALS;
    /// @notice Decimals of the base asset (e.g. USDC = 6).
    uint8 public immutable ASSET_DECIMALS;
    /// @notice Decimals of the fund share token (e.g. USTB = 6).
    uint8 public immutable SHARE_DECIMALS;
    /// @notice 1 unit of the base asset in its smallest denomination (10 ** ASSET_DECIMALS).
    uint256 public immutable ONE_ASSET;

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Shares awaiting USDC settlement after an async redemption.
    uint256 public pendingWithdrawalShares;
    /// @notice Slippage band applied to the share/asset check during `sweep`.
    Percentage public sweepSlippage;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _shareToken Superstate fund token (e.g. USTB).
     * @param _oracle Price feed returning the price of 1 share in base-asset terms.
     * @param _params Standard Ark initialization parameters.
     */
    constructor(
        address _shareToken,
        address _oracle,
        ArkParams memory _params
    ) ArkWithWithdrawalRequest(_params, DEFAULT_SWAP_SLIPPAGE) {
        if (_shareToken == address(0)) revert InvalidShareTokenAddress();
        if (_oracle == address(0)) revert InvalidOracleAddress();

        SHARE_TOKEN = IERC20Metadata(_shareToken);
        ORACLE = AggregatorV3Interface(_oracle);
        ORACLE_DECIMALS = AggregatorV3Interface(_oracle).decimals();
        SHARE_DECIMALS = IERC20Metadata(_shareToken).decimals();
        ASSET_DECIMALS = IERC20Metadata(_params.asset).decimals();
        ONE_ASSET = 10 ** ASSET_DECIMALS;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IArkWithWithdrawalRequest
    function assetsInWithdrawalQueue() public view override returns (uint256) {
        return _sharesToAssets(pendingWithdrawalShares);
    }

    /// @inheritdoc IArkWithWithdrawalRequest
    function withdrawalRequestId() external pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IArkWithWithdrawalRequest
    function isWithdrawalClaimRequired() external pure override returns (bool) {
        return false;
    }

    /// @notice Converts shares to assets at the current oracle price.
    function sharesToAssets(uint256 shares) external view returns (uint256) {
        return _sharesToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                           KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IArkWithWithdrawalRequest
    function claimWithdrawal() external override onlyKeeper {
        // No-op: Superstate delivers USDC directly to the ark.
    }

    /// @inheritdoc IArkWithWithdrawalRequest
    function withdrawUsingSwap(
        uint256,
        bytes calldata
    ) external override onlyKeeper nonReentrant {
        // No-op: Superstate arks do not perform swaps.
    }

    /// @notice Updates the sweep slippage band. Keeper-gated.
    function setSweepSlippage(Percentage newSweepSlippage) external onlyKeeper {
        _setSweepSlippage(newSweepSlippage);
    }

    /**
     * @inheritdoc IArkWithWithdrawalRequest
     * @notice Forwards any USDC sitting on the ark to the buffer ark and zeroes
     *         `pendingWithdrawalShares`. Reverts when the returned USDC, valued
     *         in shares, falls below `pendingWithdrawalShares` minus `sweepSlippage`.
     */
    function sweep()
        public
        virtual
        override
        onlyKeeper
        nonReentrant
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        uint256 returnedAssets = config.asset.balanceOf(address(this));
        uint256 returnedShares = _assetsToShares(returnedAssets);

        uint256 pendingMinusSlippage = pendingWithdrawalShares
            .subtractPercentage(sweepSlippage);

        if (returnedShares < pendingMinusSlippage) {
            revert InsufficientAssetsReturned(
                returnedAssets,
                pendingWithdrawalShares,
                returnedShares
            );
        }

        return _sweep(returnedAssets);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Zeroes `pendingWithdrawalShares` and forwards USDC to the buffer ark.
    function _sweep(
        uint256 amountToSweep
    )
        internal
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts)
    {
        IERC20 asset = config.asset;

        sweptTokens = new address[](1);
        sweptAmounts = new uint256[](1);
        sweptTokens[0] = address(asset);
        sweptAmounts[0] = amountToSweep;

        pendingWithdrawalShares = 0;

        address bufferArk = address(
            IFleetCommander(config.commander).bufferArk()
        );
        emit Disembarked(msg.sender, address(asset), amountToSweep);

        if (amountToSweep > 0 && address(this) != bufferArk) {
            asset.forceApprove(bufferArk, amountToSweep);
            IArk(bufferArk).board(amountToSweep, bytes(""));
        }

        emit ArkSwept(sweptTokens, sweptAmounts);
    }

    function _setSweepSlippage(Percentage newSweepSlippage) internal {
        if (newSweepSlippage > MAX_SWEEP_SLIPPAGE) {
            revert InvalidSweepSlippage(newSweepSlippage, MAX_SWEEP_SLIPPAGE);
        }
        emit SweepSlippageUpdated(sweepSlippage, newSweepSlippage);
        sweepSlippage = newSweepSlippage;
    }

    /// @inheritdoc Ark
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

    function _validateBoardData(bytes calldata) internal override {}

    function _validateDisembarkData(bytes calldata) internal override {}

    /*//////////////////////////////////////////////////////////////
                            ORACLE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Converts fund-token shares to base-asset amount using the oracle price.
    function _sharesToAssets(uint256 shares) internal view returns (uint256) {
        if (shares == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.invert().quote(shares);
    }

    /// @dev Converts base-asset amount to fund-token shares using the oracle price.
    function _assetsToShares(
        uint256 assetAmount
    ) internal view returns (uint256) {
        if (assetAmount == 0) return 0;
        Price memory assetPerSharePrice = _fetchOracleAssetPerSharePrice();
        return assetPerSharePrice.quote(assetAmount);
    }

    /// @dev Reads the oracle and constructs a Price(share → asset). Reverts on stale or non-positive data.
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
