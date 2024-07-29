// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ITipper} from "../interfaces/ITipper.sol";
import {IERC20, IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {FleetCommander} from "./FleetCommander.sol";
import "../errors/TipperErrors.sol";
import "../interfaces/IConfigurationManager.sol";

/// @title Tipper
/// @notice Contract implementing tip accrual functionality
/// @dev This contract is designed to be instantiated by the FleetCommander
abstract contract Tipper is ITipper {
    /// @notice The current tip rate in basis points
    /// @dev 100 basis points = 1%
    uint256 public tipRate;

    /// @notice The timestamp of the last tip accrual
    uint256 public lastTipTimestamp;

    /// @notice The address where accrued tips are sent
    address public tipJar;

    /// @notice The protocol configuration manager
    IConfigurationManager public manager;

    /// @dev Constant representing 100% in basis points
    uint256 private constant BASIS_POINTS = 10000;

    /// @dev Constant representing the number of seconds in a year
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /// @dev Constant for scaling
    uint256 private constant SCALE = 1e18;

    /// @notice Initializes the TipAccruer contract
    /// @param configurationManager The address of the ConfigurationManager contract
    /// @param initialTipRate The initialTipRate for the Fleet
    constructor(address configurationManager, uint256 initialTipRate) {
        manager = IConfigurationManager(configurationManager);

        tipRate = initialTipRate;
        tipJar = manager.tipJar();
        lastTipTimestamp = block.timestamp;
    }

    // Internal function that must be implemented by the inheriting contract
    function _mintTip(address account, uint256 amount) internal virtual;

    /// @notice Sets a new tip rate
    /// @dev Only callable by the FleetCommander. Accrues tips before changing the rate.
    /// @param newTipRate The new tip rate to set (in basis points)
    function _setTipRate(uint256 newTipRate) internal {
        if (newTipRate > BASIS_POINTS) {
            revert TipRateCannotExceedOneHundredPercent();
        }
        _accrueTip(); // Accrue tips before changing the rate
        tipRate = newTipRate;
        emit TipRateUpdated(newTipRate);
    }

    /// @notice Sets a new tip jar address
    /// @dev Only callable by the FleetCommander
    function _setTipJar() internal {
        tipJar = manager.tipJar();

        if (tipJar == address(0)) {
            revert InvalidTipJarAddress();
        }

        emit TipJarUpdated(manager.tipJar());
    }

    /// @notice Accrues tips based on the current tip rate and time elapsed
    /// @dev Only callable by the FleetCommander
    /// @return tippedShares The amount of tips accrued in shares
    function _accrueTip() internal returns (uint256 tippedShares) {
        if (tipRate == 0) return 0;

        uint256 timeElapsed = block.timestamp - lastTipTimestamp;

        if (timeElapsed == 0) return 0;

        uint256 totalShares = IERC20(address(this)).totalSupply();

        tippedShares = _calculateTip(totalShares, timeElapsed);

        if (tippedShares > 0) {
            _mintTip(tipJar, tippedShares);
            emit TipAccrued(tippedShares);
            lastTipTimestamp = block.timestamp;
        }
    }

    function _calculateTip(
        uint256 totalShares,
        uint256 timeElapsed
    ) internal view returns (uint256) {
        // Calculate the daily interest rate
        // tipRate is in basis points (1/10000)
        // SCALE is a constant for fixed-point arithmetic (e.g., 1e18)
        // Dividing by 365 days converts annual rate to rate per second
        uint256 ratePerSecond = (tipRate * SCALE) / (BASIS_POINTS * 365 days);

        // Calculate (1 + r)^t using a custom power function
        // This is the compound interest factor
        // _rpow is a function for exponentiation with fixed-point numbers
        uint256 factor = _rpow((SCALE + ratePerSecond), timeElapsed, SCALE);

        // Calculate S = P * (1 + r)^t
        // This gives the final amount after compound interest
        // Divide by SCALE to adjust for fixed-point arithmetic
        uint256 finalShares = (totalShares * factor) / SCALE;

        // Return the difference (S - P)
        // This represents the total interest (tip) earned
        return finalShares - totalShares;
    }

    /// @notice Estimates the amount of tips accrued since the last tip accrual
    /// @return The estimated amount of accrued tips
    function estimateAccruedTip() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastTipTimestamp;
        uint256 totalShares = IERC20(address(this)).totalSupply();
        return _calculateTip(totalShares, timeElapsed);
    }

    /// @notice Calculates x^n with precision of 1e18 (base)
    /// @dev Uses an optimized assembly implementation for efficiency
    /// @dev Is equivalent to exp(ln((rate))*(secondsSince))
    /// @param x The base number
    /// @param n The exponent
    /// @param base The precision factor (typically 1e18)
    /// @return z The result of x^n, representing x^n * base
    function _rpow(
        uint256 x,
        uint256 n,
        uint256 base
    ) internal pure returns (uint256 z) {
        // Step 1: Handle special cases
        if (x == 0 || n == 0) {
            return n == 0 ? base : 0;
        }

        // Step 2: Initialize z based on whether n is odd or even
        z = n % 2 == 0 ? base : x;

        // Step 3: Prepare for the main loop
        uint256 half = base / 2;

        // Step 4: Main loop - Square-and-multiply algorithm
        assembly {
            n := div(n, 2)

            for {

            } n {

            } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) {
                    revert(0, 0)
                }

                let xxRound := add(xx, half)
                if lt(xxRound, xx) {
                    revert(0, 0)
                }

                x := div(xxRound, base)

                if mod(n, 2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                        revert(0, 0)
                    }

                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) {
                        revert(0, 0)
                    }

                    z := div(zxRound, base)
                }

                n := div(n, 2)
            }
        }
    }
}
