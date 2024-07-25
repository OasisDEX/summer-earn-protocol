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
    IConfigurationManager manager;

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
        }

        lastTipTimestamp = block.timestamp;
    }

    function _calculateTip(
        uint256 totalShares,
        uint256 timeElapsed
    ) internal view returns (uint256) {
        // Calculate the daily interest rate
        // tipRate is in basis points (1/10000)
        // SCALE is a constant for fixed-point arithmetic (e.g., 1e18)
        // Dividing by 365 converts annual rate to daily rate
        uint256 dailyRate = (tipRate * SCALE) / (BASIS_POINTS * 365);

        // Convert timeElapsed from seconds to days
        // 1 days is a Solidity time unit equal to 86400 seconds
        uint256 daysElapsed = timeElapsed / 1 days;

        // Calculate (1 + r)^t using a custom power function
        // This is the compound interest factor
        // _rpow is a function for exponentiation with fixed-point numbers
        uint256 factor = _rpow((SCALE + dailyRate), daysElapsed, SCALE);

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
        // Why: We need to handle edge cases separately to avoid division by zero and ensure correct results for x=0
        if (x == 0 || n == 0) {
            return n == 0 ? base : 0;
        }

        // Step 2: Initialize z based on whether n is odd or even
        // Why: This initialization is crucial for the correctness of the square-and-multiply algorithm
        // If n is even, we start with 1 (base in fixed-point) as it won't affect the final result
        // If n is odd, we start with x as we need one factor of x in the result immediately
        z = n % 2 == 0 ? base : x;

        // Step 3: Prepare for the main loop
        // Why: We precompute half of base for efficient rounding in fixed-point arithmetic
        uint256 half = base / 2;

        // Step 4: Main loop - Square-and-multiply algorithm
        assembly {
            // Why: We divide n by 2 to start because we'll be processing the binary representation of n
            n := div(n, 2)

            for {

            } n {

            } {
                // Step 4a: Square x
                // Why: In each iteration, we square x to handle the next bit of the exponent
                let xx := mul(x, x)
                // Overflow check: ensure x * x doesn't overflow
                if iszero(eq(div(xx, x), x)) {
                    revert(0, 0)
                }

                // Step 4b: Round the squared value
                // Why: We round to maintain precision in fixed-point arithmetic
                let xxRound := add(xx, half)
                // Overflow check: ensure rounding doesn't cause overflow
                if lt(xxRound, xx) {
                    revert(0, 0)
                }

                // Step 4c: Maintain fixed-point representation
                // Why: We divide by base to keep x in the correct fixed-point format
                x := div(xxRound, base)

                // Step 4d: If n is odd, multiply z by x
                // Why: This step accumulates the result in z based on the binary representation of n
                if mod(n, 2) {
                    // Multiply the current result (z) by the current x
                    let zx := mul(z, x)
                    // Overflow check: ensure z * x doesn't overflow
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                        revert(0, 0)
                    }

                    // Round the multiplied value
                    let zxRound := add(zx, half)
                    // Overflow check: ensure rounding doesn't cause overflow
                    if lt(zxRound, zx) {
                        revert(0, 0)
                    }

                    // Update z with the new result, maintaining fixed-point representation
                    z := div(zxRound, base)
                }

                // Prepare for next iteration
                // Why: We divide n by 2 to process the next bit of the exponent
                n := div(n, 2)
            }
        }
        // At this point, z contains the final result: x^n * base
    }
}
