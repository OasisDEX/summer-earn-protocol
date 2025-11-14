// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title Bps
 * @author James Tuckett
 * @author Roberto Cano
 * @notice Custom type for Basis Points (BPS) values with associated utility functions
 * @dev This contract defines a custom Bps type and overloaded operators
 *      to perform arithmetic and comparison operations on Bps values.
 *
 *      The Bps type uses the same representation as the Percentage type from
 *      the Percentage library, but scales values by a factor of 100 to represent
 *      basis points (1 BPS = 0.01%).
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

/// @dev The factor used to convert BPS to a percentage
uint256 constant BPS_PER_PERCENTAGE = 100; // 0.01% == 1 bps

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
    return fromPercentage(toPercentage(a) + toPercentage(b));
}

/**
 * @dev Subtracts one Bps value from another
 * @param a The Bps value to subtract from
 * @param b The Bps value to subtract
 * @return The difference of a and b as a Bps
 */
function subtract(Bps a, Bps b) pure returns (Bps) {
    return fromPercentage(toPercentage(a) - toPercentage(b));
}

/**
 * @dev Multiplies two Bps values
 * @param a The first Bps value
 * @param b The second Bps value
 * @return The product as a Bps
 */
function multiply(Bps a, Bps b) pure returns (Bps) {
    return fromPercentage(toPercentage(a) * toPercentage(b));
}

/**
 * @dev Divides one Bps value by another
 * @param a The Bps value to divide
 * @param b The Bps divisor
 * @return The quotient as a Bps
 */
function divide(Bps a, Bps b) pure returns (Bps) {
    return fromPercentage(toPercentage(a) / toPercentage(b));
}

/**
 * @dev Checks if one Bps value is less than or equal to another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a <= b, false otherwise
 */
function lessOrEqualThan(Bps a, Bps b) pure returns (bool) {
    return toPercentage(a) <= toPercentage(b);
}

/**
 * @dev Checks if one Bps value is less than another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a < b, false otherwise
 */
function lessThan(Bps a, Bps b) pure returns (bool) {
    return toPercentage(a) < toPercentage(b);
}

/**
 * @dev Checks if one Bps value is greater than or equal to another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a >= b, false otherwise
 */
function greaterOrEqualThan(Bps a, Bps b) pure returns (bool) {
    return toPercentage(a) >= toPercentage(b);
}

/**
 * @dev Checks if one Bps value is greater than another
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a > b, false otherwise
 */
function greaterThan(Bps a, Bps b) pure returns (bool) {
    return toPercentage(a) > toPercentage(b);
}

/**
 * @dev Checks if two Bps values are equal
 * @param a The first Bps value
 * @param b The second Bps value
 * @return True if a == b, false otherwise
 */
function equalTo(Bps a, Bps b) pure returns (bool) {
    return toPercentage(a) == toPercentage(b);
}

/**
 * @dev Casts a uint256 to a Bps value by wrapping it
 * @param value The uint256 value to be casted
 * @return The Bps representation of the value
 */
function toBps(uint256 value) pure returns (Bps) {
    return Bps.wrap(value);
}

/**
 * @dev Casts a Bps value to a uint256 by unwrapping it
 * @param bps The Bps value to be casted
 * @return The uint256 representation of the Bps value
 */
function fromBps(Bps bps) pure returns (uint256) {
    return Bps.unwrap(bps);
}

/**
 * @dev Converts Bps to Percentage type
 * @param bps Basis points value
 * @return percentage The equivalent Percentage value
 */
function toPercentage(Bps bps) pure returns (Percentage) {
    return Percentage.wrap(fromBps(bps) / BPS_PER_PERCENTAGE);
}

/**
 * @dev Converts Percentage type to Bps
 * @param percentage The Percentage value
 * @return bps The equivalent basis points value
 */
function fromPercentage(Percentage percentage) pure returns (Bps) {
    return toBps(Percentage.unwrap(percentage) * BPS_PER_PERCENTAGE);
}
