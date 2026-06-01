// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title BPS
 * @author Roberto Cano
 * @notice Custom type for Basis Points values with associated utility functions
 * @dev This contract defines a custom BPS type and overloaded operators to perform
 *      arithmetic and comparison operations on BPS values.
 *
 *      1 BPS = 0.01%
 *      100 BPS = 1%
 *      10000 BPS = 100%
 *
 *      Because the unit is already the native scale there is no internal decimal
 *      factor beyond `BPS_FACTOR` itself, which makes constants trivial to declare:
 *
 *          BPS constant MAX_SLIPPAGE = BPS.wrap(500); // 5%
 */

/**
 * @dev Custom basis-points type as uint256
 * @notice This type is used to represent basis-point values (0 – 10000)
 */
type BPS is uint256;

/**
 * @dev Overridden operators declaration for BPS
 * @notice These operators allow for intuitive arithmetic and comparison operations
 *         on BPS values
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
} for BPS global;

/**
 * @dev The denominator for basis-point arithmetic — represents 100%
 */
uint256 constant BPS_FACTOR = 10000;

/**
 * @dev BPS value representing 100%
 */
BPS constant BPS_100 = BPS.wrap(BPS_FACTOR);

/**
 * @dev BPS value representing 1 basis point (0.01%)
 */
BPS constant BPS_1 = BPS.wrap(1);

/**
 * OPERATOR FUNCTIONS
 */

/**
 * @dev Adds two BPS values
 */
function add(BPS a, BPS b) pure returns (BPS) {
    return BPS.wrap(BPS.unwrap(a) + BPS.unwrap(b));
}

/**
 * @dev Subtracts one BPS value from another
 */
function subtract(BPS a, BPS b) pure returns (BPS) {
    return BPS.wrap(BPS.unwrap(a) - BPS.unwrap(b));
}

/**
 * @dev Multiplies two BPS values, scaling the result back to BPS
 * @dev e.g. 500 bps * 200 bps = 10 bps (5% of 2%)
 */
function multiply(BPS a, BPS b) pure returns (BPS) {
    return BPS.wrap((BPS.unwrap(a) * BPS.unwrap(b)) / BPS_FACTOR);
}

/**
 * @dev Divides one BPS value by another, scaling the result back to BPS
 * @dev e.g. 500 bps / 200 bps = 25000 bps (5% / 2% = 250%)
 */
function divide(BPS a, BPS b) pure returns (BPS) {
    return BPS.wrap((BPS.unwrap(a) * BPS_FACTOR) / BPS.unwrap(b));
}

/**
 * @dev Checks if one BPS value is less than or equal to another
 */
function lessOrEqualThan(BPS a, BPS b) pure returns (bool) {
    return BPS.unwrap(a) <= BPS.unwrap(b);
}

/**
 * @dev Checks if one BPS value is less than another
 */
function lessThan(BPS a, BPS b) pure returns (bool) {
    return BPS.unwrap(a) < BPS.unwrap(b);
}

/**
 * @dev Checks if one BPS value is greater than or equal to another
 */
function greaterOrEqualThan(BPS a, BPS b) pure returns (bool) {
    return BPS.unwrap(a) >= BPS.unwrap(b);
}

/**
 * @dev Checks if one BPS value is greater than another
 */
function greaterThan(BPS a, BPS b) pure returns (bool) {
    return BPS.unwrap(a) > BPS.unwrap(b);
}

/**
 * @dev Checks if two BPS values are equal
 */
function equalTo(BPS a, BPS b) pure returns (bool) {
    return BPS.unwrap(a) == BPS.unwrap(b);
}

/**
 * @dev Alias for equalTo
 */
function equals(BPS a, BPS b) pure returns (bool) {
    return BPS.unwrap(a) == BPS.unwrap(b);
}

/**
 * @dev Wraps a raw basis-point integer into a BPS value
 * @param value Raw basis points, e.g. 500 for 5%
 */
function toBps(uint256 value) pure returns (BPS) {
    return BPS.wrap(value);
}

/**
 * @dev Unwraps a BPS value back to a raw uint256
 */
function fromBps(BPS value) pure returns (uint256) {
    return BPS.unwrap(value);
}
