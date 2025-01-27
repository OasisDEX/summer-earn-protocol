// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title MathUtils
 * @notice Utility library for mathematical operations
 */
library MathUtils {
    /**
     * @notice Calculates x^n with precision of base (typically 1e18)
     * @dev Uses an optimized assembly implementation for efficiency
     * @dev This function handles Percentage wrapped inputs and outputs
     * @dev Is equivalent to exp(ln((rate))*(secondsSince))
     * @dev Is derived from this function on MakerDAO's Pot.sol
     *      https://github.com/makerdao/dss/blob/fa4f6630afb0624d04a003e920b0d71a00331d98/src/pot.sol#L85
     * @param wrappedX The base number wrapped as Percentage
     * @param n The exponent (not wrapped, treated as a whole number)
     * @param wrappedBase The precision factor (typically 1e18) wrapped as Percentage
     * @return result The result of x^n, representing (x^n) * base, wrapped as Percentage
     */
    function rpow(
        Percentage wrappedX,
        uint256 n,
        Percentage wrappedBase
    ) internal pure returns (Percentage result) {
        uint256 x = Percentage.unwrap(wrappedX);
        uint256 base = Percentage.unwrap(wrappedBase);
        result = Percentage.wrap(rpow(x, n, base));
    }

    /**
     * @notice Calculates x^n with precision of base (typically 1e18)
     * @dev This is an overloaded version that accepts and returns unwrapped uint256 values
     * @dev Uses the same optimized assembly implementation as the wrapped version
     * @param x The base number (unwrapped)
     * @param n The exponent (treated as a whole number)
     * @param base The precision factor (typically 1e18, unwrapped)
     * @return result The result of x^n, representing (x^n) * base (unwrapped)
     */
    function rpow(
        uint256 x,
        uint256 n,
        uint256 base
    ) internal pure returns (uint256 result) {
        // Step 1: Handle special cases
        if (x == 0 || n == 0) {
            return n == 0 ? base : 0;
        }

        // Step 2: Initialize result is based on whether n is odd or even
        result = n % 2 == 0 ? base : x;

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
    }
}
