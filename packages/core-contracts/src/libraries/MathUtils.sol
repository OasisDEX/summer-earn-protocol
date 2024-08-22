// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Percentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title MathUtils
 * @notice Utility library for mathematical operations
 */
library MathUtils {
    /**
     * @notice Calculates x^n with precision of 1e18 (base)
     * @dev Uses an optimized assembly implementation for efficiency
     * @dev Is equivalent to exp(ln((rate))*(secondsSince))
     * @dev Is derived from this function on MakerDAO's Pot.sol
     *      https://github.com/makerdao/dss/blob/fa4f6630afb0624d04a003e920b0d71a00331d98/src/pot.sol#L85
     * @param wrappedX The base number wrapped as Percentage
     * @param n The exponent
     * @param wrappedBase The precision factor (typically 1e18) wrapped as Percentage
     * @return z The result of x^n, representing x^n * base wrapped as Percentage
     */
    function rpow(
        Percentage wrappedX,
        uint256 n,
        Percentage wrappedBase
    ) internal pure returns (Percentage z) {
        uint256 x = Percentage.unwrap(wrappedX);
        uint256 base = Percentage.unwrap(wrappedBase);
        uint256 result;

        // Step 1: Handle special cases
        if (x == 0 || n == 0) {
            return n == 0 ? wrappedBase : toPercentage(0);
        }

        // Step 2: Initialize result is based on whether n is odd or even
        result = n % 2 == 0 ? base : x;

        // Step 3: Prepare for the main loop
        uint256 half = base / 2;

        // Step 4: Main loop - Square-and-multiply algorithm
        assembly {
            n := div(n, 2)

            for {} n {} {
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
                    let zx := mul(result, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), result))) {
                        revert(0, 0)
                    }

                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) {
                        revert(0, 0)
                    }

                    result := div(zxRound, base)
                }

                n := div(n, 2)
            }
        }

        return Percentage.wrap(result);
    }
}
