// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFlexibleTipper} from "../interfaces/IFlexibleTipper.sol";
import {Tipper} from "./Tipper.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title FlexibleTipper
 * @notice Extends the base Tipper with an optional High-Water Mark (HWM) performance fee.
 * @dev This contract supports three fee modes:
 *      - AUM: Time-based assets-under-management fee (original Tipper behavior)
 *      - PERFORMANCE: HWM-based fee charged only on new profit above the high-water mark
 *      - BOTH: AUM + PERFORMANCE fees applied together
 *
 * Performance Fee Mechanism:
 * - Tracks the highest-ever assets-per-share ratio as the HWM
 * - Only charges fees when current assets-per-share exceeds the HWM
 * - After loss, no fee is charged until recovery past the old HWM
 * - Fee is taken by minting new shares to the tip jar (dilution model)
 *
 * Important:
 * 1. The inheriting contract MUST implement `_getTotalAssetsForFee()`
 * 2. The inheriting contract MUST be ERC20-compliant (same as Tipper)
 * 3. When fee type changes, HWM resets to current assetsPerShare
 */
abstract contract FlexibleTipper is IFlexibleTipper, Tipper {
    using PercentageUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The maximum performance fee rate is 50%
    Percentage immutable MAX_PERFORMANCE_FEE_RATE = Percentage.wrap(50 * 1e18);

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The current fee type (AUM, PERFORMANCE, or BOTH)
    FeeType public feeType;

    /// @notice The current performance fee rate (as Percentage, max 50%)
    Percentage public performanceFeeRate;

    /// @notice The highest-ever assets-per-share ratio, scaled by 1e18
    /// @dev Used as the baseline for performance fee calculations.
    ///      Performance fees are only charged on profit above this mark.
    uint256 public highWaterMark;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the FlexibleTipper contract
     * @param initialTipRate The initial AUM tip rate for the Fleet
     * @dev Sets default fee type to AUM and HWM to 1e18 (1:1 ratio)
     */
    constructor(Percentage initialTipRate) Tipper(initialTipRate) {
        feeType = FeeType.AUM;
        highWaterMark = 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the fee type and resets HWM to current assetsPerShare
     * @param newFeeType The new fee type to set
     * @param _totalAssets The current total assets (passed to avoid re-computation)
     * @param _totalSupply The current total supply (passed to avoid re-computation)
     * @dev Resets HWM to current assetsPerShare to prevent "dead HWM" after drawdowns.
     *      The FeeTypeChanged event logs old and new HWM for on-chain auditability.
     */
    function _setFeeType(
        FeeType newFeeType,
        uint256 _totalAssets,
        uint256 _totalSupply
    ) internal {
        FeeType oldFeeType = feeType;
        uint256 oldHWM = highWaterMark;

        feeType = newFeeType;

        // Reset HWM to current assetsPerShare
        uint256 newHWM;
        if (_totalSupply > 0) {
            newHWM = (_totalAssets * 1e18) / _totalSupply;
        } else {
            newHWM = 1e18; // Default 1:1 when no shares exist
        }
        highWaterMark = newHWM;

        emit FeeTypeChanged(oldFeeType, newFeeType, oldHWM, newHWM);
    }

    /**
     * @notice Sets the performance fee rate
     * @param newRate The new performance fee rate
     * @dev Reverts if the rate exceeds 50%
     */
    function _setPerformanceFeeRate(
        Percentage newRate,
        address tipJar,
        uint256 _totalSupply
    ) internal {
        if (newRate > MAX_PERFORMANCE_FEE_RATE) {
            revert PerformanceFeeRateTooHigh();
        }
        _accrueTip(tipJar, _totalSupply);
        performanceFeeRate = newRate;
        emit PerformanceFeeRateUpdated(newRate);
    }

    /*//////////////////////////////////////////////////////////////
                    TIP ACCRUAL (OVERRIDE)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Accrues tips based on the current fee type
     * @dev Overrides Tipper._accrueTip to support performance and combined fees.
     *      For AUM mode: delegates to super._accrueTip (original Tipper logic)
     *      For PERFORMANCE mode: only charges HWM-based fee
     *      For BOTH mode: charges AUM first, then performance on post-AUM supply
     * @param tipJar The address of the tip jar
     * @param _totalSupply The total supply of shares
     * @return totalFeeShares The total amount of fee shares minted
     */
    function _accrueTip(
        address tipJar,
        uint256 _totalSupply
    ) internal virtual override returns (uint256 totalFeeShares) {
        uint256 aumShares = 0;
        uint256 perfShares = 0;

        // AUM fee (delegate to base Tipper logic)
        if (feeType == FeeType.AUM || feeType == FeeType.BOTH) {
            aumShares = super._accrueTip(tipJar, _totalSupply);
        } else {
            // Even if not charging AUM, we still update the timestamp
            lastTipTimestamp = block.timestamp;
        }

        // Performance fee (uses post-AUM supply for accurate dilution)
        if (feeType == FeeType.PERFORMANCE || feeType == FeeType.BOTH) {
            uint256 supplyAfterAUM = _totalSupply + aumShares;
            perfShares = _accruePerformanceFee(tipJar, supplyAfterAUM);
        }

        totalFeeShares = aumShares + perfShares;
    }

    /*//////////////////////////////////////////////////////////////
                PERFORMANCE FEE INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates and mints performance fee shares based on the HWM model
     * @dev Fee is only charged when current assetsPerShare exceeds the highWaterMark.
     *      After minting fee shares, the HWM is updated to the current assetsPerShare.
     *
     * Optimized Direct Share Calculation:
     *   We want to mint shares such that the value of those shares equals
     *   (Performance Fee Rate) * (Growth in Assets).
     *
     *   feeShares = totalSupply * rate * (currentAPS - HWM) / currentAPS
     *
     *   This is algebraically equivalent to the expanded form:
     *     profitPerShare  = currentAPS - HWM
     *     totalProfit     = profitPerShare * totalSupply / 1e18
     *     feeAssets       = totalProfit * rate
     *     feeShares       = feeAssets * totalSupply / totalAssets
     *   but uses 2 divisions instead of 3, reducing rounding truncation.
     *
     * @param tipJar The address to receive the fee shares
     * @param _totalSupply The current total supply (post-AUM if in BOTH mode)
     * @return feeShares The number of shares minted as performance fee
     */
    function _accruePerformanceFee(
        address tipJar,
        uint256 _totalSupply
    ) internal virtual returns (uint256 feeShares) {
        if (_totalSupply == 0) return 0;

        // Cache rate to save gas on multiple reads
        Percentage rate = performanceFeeRate;
        if (Percentage.unwrap(rate) == 0) return 0;

        uint256 currentTotalAssets = _getTotalAssetsForFee();
        // 1e18 scaling for the ratio calculation
        uint256 currentAPS = (currentTotalAssets * 1e18) / _totalSupply;

        // Standard HWM check
        if (currentAPS <= highWaterMark) return 0;

        /**
         * Dilution-Aware Math:
         * We want to mint shares (sf) such that sf / (S + sf) = FeeAssets / TotalAssets.
         *
         * sf = (S * FeeAssets) / (TotalAssets - FeeAssets)
         *
         * In share-price terms (dividing by S/1e18):
         * FeeAssetsPerShare = (currentAPS - HWM) * rate
         * sf = (S * FeeAssetsPerShare) / (currentAPS - FeeAssetsPerShare)
         */
        uint256 profitPerShare = currentAPS - highWaterMark;
        uint256 feeAssetsPerShare = profitPerShare.applyPercentage(rate);

        // Calculate fee shares using the dilution-aware formula
        feeShares =
            (_totalSupply * feeAssetsPerShare) /
            (currentAPS - feeAssetsPerShare);

        if (feeShares > 0) {
            _mintTip(tipJar, feeShares);

            // Update HWM to the post-mint APS to prevent artificial drawdown
            highWaterMark =
                (currentTotalAssets * 1e18) /
                (_totalSupply + feeShares);

            emit PerformanceFeeAccrued(feeShares);
            emit HighWaterMarkUpdated(highWaterMark);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TIP PREVIEW (VIEW)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Previews the total tip shares (AUM + performance) that would be
     *         minted if _accrueTip were called now.
     * @dev Overrides Tipper.previewTip to include the performance fee estimate.
     *      This ensures totalSupply() in view context (used by ERC4626 preview*
     *      and max* functions) reflects the pending performance fee dilution.
     *
     * @param tipJar The address of the tip jar
     * @param _totalSupply The raw total supply (pre-tip)
     * @return tippedShares Total shares that would be minted (AUM + performance)
     */
    function previewTip(
        address tipJar,
        uint256 _totalSupply
    ) public view override returns (uint256 tippedShares) {
        // 1. AUM preview (delegate to base Tipper)
        if (feeType == FeeType.AUM || feeType == FeeType.BOTH) {
            tippedShares += super.previewTip(tipJar, _totalSupply);
        }

        // 2. Performance fee preview
        if (feeType == FeeType.PERFORMANCE || feeType == FeeType.BOTH) {
            uint256 supplyAfterAUM = _totalSupply + tippedShares;
            tippedShares += _previewPerformanceFee(supplyAfterAUM);
        }
    }

    /**
     * @notice Pure view estimate of performance fee shares without state mutation.
     * @dev Mirrors the math in _accruePerformanceFee but reads _getTotalAssetsForFee()
     *      without caching. This may be gas-expensive when called outside a cached context
     *      (e.g., external view calls), but is necessary for accurate previews.
     *
     * @param _totalSupply The supply to use (post-AUM if in BOTH mode)
     * @return feeShares The estimated performance fee shares
     */
    function _previewPerformanceFee(
        uint256 _totalSupply
    ) internal view returns (uint256 feeShares) {
        if (_totalSupply == 0) return 0;

        Percentage rate = performanceFeeRate;
        if (Percentage.unwrap(rate) == 0) return 0;

        uint256 currentTotalAssets = _getTotalAssetsForFee();
        uint256 currentAPS = (currentTotalAssets * 1e18) / _totalSupply;

        if (currentAPS <= highWaterMark) return 0;

        uint256 profitPerShare = currentAPS - highWaterMark;
        uint256 feeAssetsPerShare = profitPerShare.applyPercentage(rate);

        feeShares =
            (_totalSupply * feeAssetsPerShare) /
            (currentAPS - feeAssetsPerShare);
    }

    /*//////////////////////////////////////////////////////////////
                        ABSTRACT HOOKS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total assets for fee calculation
     * @dev Must be implemented by the inheriting FleetCommander.
     *      Should return the current totalAssets() value.
     *      This hook allows the FlexibleTipper to remain abstract and
     *      not depend on ERC4626 directly.
     * @return The total assets held by the vault
     */
    function _getTotalAssetsForFee() internal view virtual returns (uint256);
}
