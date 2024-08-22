// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {UD60x18, ud, unwrap} from "@prb/math/src/UD60x18.sol";

/**
 * @title VotingDecayMath
 * @notice A library for precise mathematical operations used in voting decay calculations
 * @dev Utilizes PRBMath for high-precision fixed-point arithmetic
 */
library VotingDecayMath {
    /// @notice Constant representing 1 in 18 decimal fixed-point format (1e18)
    uint256 private constant WAD = 1e18;

    /**
     * @notice Performs a high-precision multiplication followed by a division
     * @dev Uses PRBMath's UD60x18 type for increased accuracy
     * @param a The first factor
     * @param b The second factor
     * @param denominator The divisor
     * @return The result of (a * b) / denominator, with 18 decimal precision
     */
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256) {
        UD60x18 result = ud(a).mul(ud(b)).div(ud(denominator));
        return unwrap(result);
    }

    /**
     * @notice Calculates the exponential decay of a value over time
     * @dev Uses PRBMath for high-precision exponential calculation
     * @param initialValue The starting value before decay
     * @param decayRatePerSecond The rate of decay per second (in WAD format)
     * @param decayTimeInSeconds The duration of decay in seconds
     * @return The decayed value, with 18 decimal precision
     */
    function exponentialDecay(
        uint256 initialValue,
        uint256 decayRatePerSecond,
        uint256 decayTimeInSeconds
    ) internal pure returns (uint256) {
        if (decayTimeInSeconds == 0 || decayRatePerSecond == 0) {
            return initialValue;
        }

        UD60x18 retentionRatePerSecond = ud(WAD - decayRatePerSecond);
        UD60x18 retentionFactor = retentionRatePerSecond.powu(
            decayTimeInSeconds
        );
        UD60x18 result = ud(initialValue).mul(retentionFactor);

        return unwrap(result.gt(ud(0)) ? result.div(ud(1e18)) : ud(0));
    }

    /**
     * @notice Calculates the linear decay of a value over time
     * @dev Applies a constant rate of decay per unit of time
     * @param initialValue The starting value before decay
     * @param decayRatePerSecond The rate of decay per second (in WAD format)
     * @param decayTimeInSeconds The duration of decay in seconds
     * @return The decayed value, with 18 decimal precision
     */
    function linearDecay(
        uint256 initialValue,
        uint256 decayRatePerSecond,
        uint256 decayTimeInSeconds
    ) internal pure returns (uint256) {
        uint256 totalDecayFactor = decayRatePerSecond * decayTimeInSeconds;
        uint256 retentionFactor = WAD - totalDecayFactor;

        return (initialValue * retentionFactor) / WAD;
    }
}
