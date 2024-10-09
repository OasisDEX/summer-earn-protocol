// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ITipper} from "../interfaces/ITipper.sol";
import {IERC20, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ConfigurationManaged} from "./ConfigurationManaged.sol";

import {Constants} from "./libraries/Constants.sol";
import {MathUtils} from "@summerfi/math-utils/contracts/MathUtils.sol";
import {PERCENTAGE_100, Percentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
/**
 * @title Tipper
 * @notice Contract implementing tip accrual functionality
 * @dev This contract is designed to be inherited by ERC20-compliant contracts.
 *      It relies on the inheriting contract to implement ERC20 functionality,
 *      particularly the totalSupply() function.
 *
 * Important:
 * 1. The inheriting contract MUST be ERC20-compliant.
 * 2. The inheriting contract MUST implement the _mintTip function.
 * 3. The contract uses its own address as the token for calculations,
 *    assuming it represents shares in the system.
 */
abstract contract Tipper is ITipper, ConfigurationManaged {
    using PercentageUtils for uint256;
    using MathUtils for Percentage;

    /**
     * @notice The current tip rate (as Percentage)
     * @dev Percentages have 18 decimals of precision
     */
    Percentage public tipRate;

    /**
     * @notice The timestamp of the last tip accrual
     */
    uint256 public lastTipTimestamp;

    /**
     * @notice Initializes the TipAccruer contract
     * @param configurationManager The address of the ConfigurationManager contract
     * @param initialTipRate The initialTipRate for the Fleet
     */
    constructor(
        address configurationManager,
        Percentage initialTipRate
    ) ConfigurationManaged(configurationManager) {
        tipRate = initialTipRate;
        lastTipTimestamp = block.timestamp;
    }

    /**
     * @notice Abstract function to mint new shares as tips
     * @dev This function is meant to be overridden by inheriting contracts.
     *      It is called internally by the _accrueTip function to mint new shares as tips.
     *      The implementation should create new shares for the specified account
     *      without requiring additional underlying assets.
     * @param account The address to receive the minted tip shares
     * @param amount The amount of shares to mint as a tip
     */
    function _mintTip(address account, uint256 amount) internal virtual;

    /**
     * @notice Sets a new tip rate
     * @dev Only callable by the FleetCommander. Accrues tips before changing the rate.
     * @param newTipRate The new tip rate to set (in basis points)
     */
    function _setTipRate(Percentage newTipRate) internal {
        if (!PercentageUtils.isPercentageInRange(newTipRate)) {
            revert TipRateCannotExceedOneHundredPercent();
        }
        _accrueTip(); // Accrue tips before changing the rate
        tipRate = newTipRate;
        emit TipRateUpdated(newTipRate);
    }

    /**
     * @notice Accrues tips based on the current tip rate and time elapsed
     * @dev Only callable by the FleetCommander
     * @return tippedShares The amount of tips accrued in shares
     */
    function _accrueTip() internal returns (uint256 tippedShares) {
        if (tipRate == toPercentage(0)) {
            lastTipTimestamp = block.timestamp;
            return 0;
        }

        uint256 timeElapsed = block.timestamp - lastTipTimestamp;

        if (timeElapsed == 0) return 0;

        // Note: This line assumes the contract itself is an ERC20 token
        uint256 totalShares = IERC20(address(this)).totalSupply();

        tippedShares = _calculateTip(totalShares, timeElapsed);

        if (tippedShares > 0) {
            _mintTip(tipJar(), tippedShares);
            lastTipTimestamp = block.timestamp;
            emit TipAccrued(tippedShares);
        }
    }

    function _calculateTip(
        uint256 totalShares,
        uint256 timeElapsed
    ) internal view returns (uint256) {
        Percentage ratePerSecond = Percentage.wrap(
            (Percentage.unwrap(tipRate) / Constants.SECONDS_PER_YEAR)
        );

        // Calculate (1 + r)^t using a custom power function
        Percentage factor = MathUtils.rpow(
            PERCENTAGE_100 + ratePerSecond,
            timeElapsed,
            PERCENTAGE_100
        );

        // Calculate S = P * (1 + r)^t
        uint256 finalShares = totalShares.applyPercentage(factor);

        // Return the difference (S - P)
        // This represents the total interest (tip) earned

        return finalShares - totalShares;
    }

    /**
     * @notice Estimates the amount of tips accrued since the last tip accrual
     * @return The estimated amount of accrued tips
     */
    function estimateAccruedTip() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastTipTimestamp;
        uint256 totalShares = IERC20(address(this)).totalSupply();
        return _calculateTip(totalShares, timeElapsed);
    }
}
