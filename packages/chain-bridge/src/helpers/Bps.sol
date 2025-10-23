// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title Bps
 * @author James Tuckett
 * @notice Custom type for Basis Points (BPS) values with associated utility functions
 * @dev This contract defines a custom Bps type and overloaded operators
 *      to perform arithmetic and comparison operations on Bps values.
 */

/**
 * @dev Custom basis points type as uint256
 * @notice This type is used to represent basis points values (1 BPS = 0.01%)
 */
type Bps is uint256;

/**
 * @dev Overridden operators declaration for Bps
 * @notice These operators allow for intuitive arithmetic and comparison operations
 *         on Bps values
 */
using {
    add as +,
    subtract as -,
    multiply as *,
    divide as /,
    lessOrEqualThan as <=,
    lessThan as <,
    greaterOrEqualThan as >=,
    greaterThan as >,
    equalTo as ==
} for Bps global;

/**
 * @dev The factor used for basis points calculations
 *  This constant is used to convert between human-readable basis points
 *         and the internal representation (10000 = 100%)
 */
uint256 constant BPS_FACTOR = 10000;

/**
 * @dev BPS of 100% (10000 basis points)
 *  This constant represents 100% in the Bps type
 */
Bps constant BPS_100 = Bps.wrap(10000);

/**
 * @dev BPS of 1% (100 basis points)
 *  This constant represents 1% in the Bps type
 */
Bps constant BPS_1 = Bps.wrap(100);

/**
 * @dev BPS of 10% (1000 basis points)
 *  This constant represents 10% in the Bps type
 */
Bps constant BPS_10 = Bps.wrap(1000);

/**
 * @dev BPS of 0.5% (50 basis points)
 *  This constant represents 0.5% in the Bps type
 */
Bps constant BPS_0_5 = Bps.wrap(50);

/**
 * OPERATOR FUNCTIONS
 */

/**
 * @dev Adds two Bps values
 * @param a The first Bps value
 * @param b The second Bps value
 * @return The sum of a and b as a Bps
 */
function add(Bps a, Bps b) pure returns (Bps) {
    return Bps.wrap(Bps.unwrap(a) + Bps.unwrap(b));
}

/**
 * @dev Subtracts one Bps value from another
 * @param a The Bps value to subtract from
 * @param b The Bps value to subtract
 * @return The difference of a and b as a Bps
 */
function subtract(Bps a, Bps b) pure returns (Bps) {
    return Bps.wrap(Bps.unwrap(a) - Bps.unwrap(b));
}

/**
 * @dev Multiplies two Bps values
 * @param a The first Bps value
 * @param b The second Bps value
 * @return The product as a Bps
 */
function multiply(Bps a, Bps b) pure returns (Bps) {
    return Bps.wrap(Bps.unwrap(a) * Bps.unwrap(b));
}

/**
 * @dev Divides one Bps value by another
 * @param a The Bps value to divide
 * @param b The Bps divisor
 * @return The quotient as a Bps
 */
function divide(Bps a, Bps b) pure returns (Bps) {
    return Bps.wrap(Bps.unwrap(a) / Bps.unwrap(b));
}

/**
 * @dev Checks if one Bps value is less than or equal to another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a <= b, false otherwise
 */
function lessOrEqualThan(Bps a, Bps b) pure returns (bool) {
    return Bps.unwrap(a) <= Bps.unwrap(b);
}

/**
 * @dev Checks if one Bps value is less than another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a < b, false otherwise
 */
function lessThan(Bps a, Bps b) pure returns (bool) {
    return Bps.unwrap(a) < Bps.unwrap(b);
}

/**
 * @dev Checks if one Bps value is greater than or equal to another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a >= b, false otherwise
 */
function greaterOrEqualThan(Bps a, Bps b) pure returns (bool) {
    return Bps.unwrap(a) >= Bps.unwrap(b);
}

/**
 * @dev Checks if one Bps value is greater than another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a > b, false otherwise
 */
function greaterThan(Bps a, Bps b) pure returns (bool) {
    return Bps.unwrap(a) > Bps.unwrap(b);
}

/**
 * @dev Checks if two Bps values are equal
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a == b, false otherwise
 */
function equalTo(Bps a, Bps b) pure returns (bool) {
    return Bps.unwrap(a) == Bps.unwrap(b);
}

/**
 * @dev Converts a uint256 to a Bps value
 * @param value The uint256 value to convert
 * @return The Bps representation of the value
 */
function toBps(uint256 value) pure returns (Bps) {
    return Bps.wrap(value);
}

/**
 * @dev Converts a Bps value to a uint256
 * @param bps The Bps value to convert
 * @return The uint256 representation of the Bps value
 */
function fromBps(Bps bps) pure returns (uint256) {
    return Bps.unwrap(bps);
}
