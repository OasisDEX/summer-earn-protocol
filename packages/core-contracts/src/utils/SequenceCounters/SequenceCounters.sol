// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title SequenceCounters
 * @author robercano
 * @notice Utility library for managing sequence counters that are only incremented
 * @dev This library defines a custom SequenceCounter type and associated utility functions
 *      to manage sequence counters that can only be incremented. Replaces the disappeared
 *      OpenZeppelin Counters library for this specific use case.
 */
struct SequenceCounter {
    uint256 _value; // Internal value of the counter
}

/**
 * @title SequenceCounters
 * @notice Utility library for managing sequence counters that are only incremented
 */
library SequenceCounters {
    /**
     * @dev Increments the SequenceCounter value by 1
     *
     * @param counter The SequenceCounter to increment
     
     * @return The new value of the SequenceCounter after incrementing
     */
    function increment(
        SequenceCounter storage counter
    ) internal returns (uint256) {
        return ++counter._value;
    }

    /**
     * @dev Returns the current value of the SequenceCounter
     *
     * @param counter The SequenceCounter to query
     *
     * @return The current value of the SequenceCounter
     */
    function current(
        SequenceCounter storage counter
    ) internal view returns (uint256) {
        return counter._value;
    }

    /**
     * @dev Checks if one SequenceCounter value is less than or equal to another
     * @param a The first SequenceCounter value
     * @param b The second SequenceCounter value
     * @return True if a is less than or equal to b, false otherwise
     */
    function lessOrEqualThan(
        SequenceCounter storage a,
        SequenceCounter storage b
    ) internal view returns (bool) {
        return a._value <= b._value;
    }

    /**
     * @dev Checks if one SequenceCounter value is less than another
     * @param a The first SequenceCounter value
     * @param b The second SequenceCounter value
     * @return True if a is less than b, false otherwise
     */
    function lessThan(
        SequenceCounter storage a,
        SequenceCounter storage b
    ) internal view returns (bool) {
        return a._value < b._value;
    }

    /**
     * @dev Checks if one SequenceCounter value is greater than or equal to another
     * @param a The first SequenceCounter value
     * @param b The second SequenceCounter value
     * @return True if a is greater than or equal to b, false otherwise
     */
    function greaterOrEqualThan(
        SequenceCounter storage a,
        SequenceCounter storage b
    ) internal view returns (bool) {
        return a._value >= b._value;
    }

    /**
     * @dev Checks if one SequenceCounter value is greater than another
     * @param a The first SequenceCounter value
     * @param b The second SequenceCounter value
     * @return True if a is greater than b, false otherwise
     */
    function greaterThan(
        SequenceCounter storage a,
        SequenceCounter storage b
    ) internal view returns (bool) {
        return a._value > b._value;
    }

    /**
     * @dev Checks if two SequenceCounter values are equal
     * @param a The first SequenceCounter value
     * @param b The second SequenceCounter value
     * @return True if a is equal to b, false otherwise
     */
    function equalTo(
        SequenceCounter storage a,
        SequenceCounter storage b
    ) internal view returns (bool) {
        return a._value == b._value;
    }
}
