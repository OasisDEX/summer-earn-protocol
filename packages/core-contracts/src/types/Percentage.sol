// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title Percentage
 *     @notice Custom type for Percentage values
 */

/**
 * Custom percentage type as uint256
 */
type Percentage is uint256;

/**
 * Overriden operators declaration for Percentage
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
} for Percentage global;

/* The number of decimals used for the slippage percentage */
uint256 constant PERCENTAGE_DECIMALS = 6;

/* The factor used to scale the slippage percentage when calculating the slippage on an amount */
uint256 constant PERCENTAGE_FACTOR = 10 ** PERCENTAGE_DECIMALS;

/* Percentage of 100% with the given `PERCENTAGE_DECIMALS` */
Percentage constant PERCENTAGE_100 = Percentage.wrap(100 * PERCENTAGE_FACTOR);

/**
 * OPERATOR FUNCTIONS
 */
function add(Percentage a, Percentage b) pure returns (Percentage) {
    return Percentage.wrap(Percentage.unwrap(a) + Percentage.unwrap(b));
}

function subtract(Percentage a, Percentage b) pure returns (Percentage) {
    return Percentage.wrap(Percentage.unwrap(a) - Percentage.unwrap(b));
}

function multiply(Percentage a, Percentage b) pure returns (Percentage) {
    return
        Percentage.wrap(
            (Percentage.unwrap(a) * Percentage.unwrap(b)) /
                Percentage.unwrap(PERCENTAGE_100)
        );
}

function divide(Percentage a, Percentage b) pure returns (Percentage) {
    return
        Percentage.wrap(
            (Percentage.unwrap(a) * Percentage.unwrap(PERCENTAGE_100)) /
                Percentage.unwrap(b)
        );
}

function lessOrEqualThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) <= Percentage.unwrap(b);
}

function lessThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) < Percentage.unwrap(b);
}

function greaterOrEqualThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) >= Percentage.unwrap(b);
}

function greaterThan(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) > Percentage.unwrap(b);
}

function equalTo(Percentage a, Percentage b) pure returns (bool) {
    return Percentage.unwrap(a) == Percentage.unwrap(b);
}
