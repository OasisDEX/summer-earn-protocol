// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ITipper} from "../interfaces/ITipper.sol";
import {IERC20, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FleetCommander} from "./FleetCommander.sol";
import "../errors/TipperErrors.sol";
import "../interfaces/IConfigurationManager.sol";
import "../types/Percentage.sol";
import "../libraries/PercentageUtils.sol";

/**
 * @title Tipper
 * @notice Contract implementing tip accrual functionality
 */
abstract contract Tipper is ITipper {
    using PercentageUtils for uint256;

    /** @notice The current tip rate in basis points */
    Percentage public tipRate;

    /** @notice The timestamp of the last tip accrual */
    uint256 public lastTipTimestamp;

    /** @notice The address where accrued tips are sent */
    address public tipJar;

    /** @notice The protocol configuration manager */
    IConfigurationManager public manager;

    /** @dev Constant representing the number of seconds in a year */
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /**
     * @notice Initializes the TipAccruer contract
     * @param configurationManager The address of the ConfigurationManager contract
     * @param initialTipRate The initialTipRate for the Fleet
     */
    constructor(address configurationManager, Percentage initialTipRate) {
        manager = IConfigurationManager(configurationManager);

        tipRate = initialTipRate;
        tipJar = manager.tipJar();
        lastTipTimestamp = block.timestamp;
    }

    // Internal function that must be implemented by the inheriting contract
    function _mintTip(address account, uint256 amount) internal virtual;

    /**
     * @notice Sets a new tip rate
     * @dev Only callable by the FleetCommander. Accrues tips before changing the rate.
     * @param newTipRate The new tip rate to set (in basis points)
     */
    function _setTipRate(Percentage newTipRate) internal {
        if (newTipRate > PERCENTAGE_100) {
            revert TipRateCannotExceedOneHundredPercent();
        }
        _accrueTip(); // Accrue tips before changing the rate
        tipRate = newTipRate;
        emit TipRateUpdated(newTipRate);
    }

    /**
     * @notice Sets a new tip jar address
     * @dev Only callable by the FleetCommander
     */
    function _setTipJar() internal {
        tipJar = manager.tipJar();

        if (tipJar == address(0)) {
            revert InvalidTipJarAddress();
        }

        emit TipJarUpdated(manager.tipJar());
    }

    /**
     * @notice Accrues tips based on the current tip rate and time elapsed
     * @dev Only callable by the FleetCommander
     * @return tippedShares The amount of tips accrued in shares
     */
    function _accrueTip() internal returns (uint256 tippedShares) {
        if (Percentage.unwrap(tipRate) == 0) {
            lastTipTimestamp = block.timestamp;
            return 0;
        }

        uint256 timeElapsed = block.timestamp - lastTipTimestamp;

        if (timeElapsed == 0) return 0;

        uint256 totalShares = IERC20(address(this)).totalSupply();

        tippedShares = _calculateTip(totalShares, timeElapsed);

        if (tippedShares > 0) {
            _mintTip(tipJar, tippedShares);
            lastTipTimestamp = block.timestamp;
            emit TipAccrued(tippedShares);
        }
    }

    function _calculateTip(
        uint256 totalShares,
        uint256 timeElapsed
    ) internal view returns (uint256) {
        Percentage ratePerSecond = Percentage.wrap(
            (Percentage.unwrap(tipRate) / SECONDS_PER_YEAR)
        );

        // Calculate (1 + r)^t using a custom power function
        Percentage factor = _rpow(
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

    /**
     * @notice Calculates x^n with precision of 1e18 (base)
     * @dev Uses an optimized assembly implementation for efficiency
     * @dev Is equivalent to exp(ln((rate))*(secondsSince))
     * @param x The base number
     * @param n The exponent
     * @param base The precision factor (typically 1e18)
     * @return z The result of x^n, representing x^n * base
     */
    function _rpow(
        Percentage x,
        uint256 n,
        Percentage base
    ) internal pure returns (Percentage z) {
        uint256 xUnwrapped = Percentage.unwrap(x);
        uint256 baseUnwrapped = Percentage.unwrap(base);
        uint256 result;

        // Step 1: Handle special cases
        if (xUnwrapped == 0 || n == 0) {
            return n == 0 ? base : Percentage.wrap(0);
        }

        // Step 2: Initialize result is based on whether n is odd or even
        result = n % 2 == 0 ? baseUnwrapped : xUnwrapped;

        // Step 3: Prepare for the main loop
        uint256 half = baseUnwrapped / 2;

        // Step 4: Main loop - Square-and-multiply algorithm
        assembly {
            n := div(n, 2)

            for {

            } n {

            } {
                let xx := mul(xUnwrapped, xUnwrapped)
                if iszero(eq(div(xx, xUnwrapped), xUnwrapped)) {
                    revert(0, 0)
                }

                let xxRound := add(xx, half)
                if lt(xxRound, xx) {
                    revert(0, 0)
                }

                xUnwrapped := div(xxRound, baseUnwrapped)

                if mod(n, 2) {
                    let zx := mul(result, xUnwrapped)
                    if and(
                        iszero(iszero(xUnwrapped)),
                        iszero(eq(div(zx, xUnwrapped), result))
                    ) {
                        revert(0, 0)
                    }

                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) {
                        revert(0, 0)
                    }

                    result := div(zxRound, baseUnwrapped)
                }

                n := div(n, 2)
            }
        }

        return Percentage.wrap(result);
    }
}
