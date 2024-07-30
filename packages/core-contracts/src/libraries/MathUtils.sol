// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../types/Percentage.sol";

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
     * @param x The base number
     * @param n The exponent
     * @param base The precision factor (typically 1e18)
     * @return z The result of x^n, representing x^n * base
     */
    function rpow(
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
