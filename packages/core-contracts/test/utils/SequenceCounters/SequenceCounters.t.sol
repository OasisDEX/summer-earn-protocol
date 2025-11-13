// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import "../../../src/utils/SequenceCounters/SequenceCounters.sol";

contract SequenceCountersTest is Test {
    using SequenceCounters for SequenceCounter;

    SequenceCounter counter;
    SequenceCounter counterA;
    SequenceCounter counterB;

    function test_Current() public {
        {
            counter = SequenceCounter(42);
            uint256 currentValue = counter.current();
            assertEq(currentValue, 42);
        }
        {
            counter = SequenceCounter(918239283);
            uint256 currentValue = counter.current();
            assertEq(currentValue, 918239283);
        }
    }

    function test_Increment() public {
        {
            counter = SequenceCounter(0);
            uint256 newValue = counter.increment();
            assertEq(counter.current(), 1);
            assertEq(newValue, 1);

            newValue = counter.increment();
            assertEq(counter.current(), 2);
            assertEq(newValue, 2);
        }
        {
            counter = SequenceCounter(42);
            uint256 newValue = counter.increment();
            assertEq(counter.current(), 43);
            assertEq(newValue, 43);
        }
    }

    function test_LessOrEqualThan() public {
        counterA = SequenceCounter(42);
        counterB = SequenceCounter(100);
        assertTrue(counterA.lessOrEqualThan(counterB));
    }

    function test_LessThan() public {
        counterA = SequenceCounter(42);
        counterB = SequenceCounter(100);
        assertTrue(counterA.lessThan(counterB));
    }

    function test_GreaterOrEqualThan() public {
        counterA = SequenceCounter(100);
        counterB = SequenceCounter(42);
        assertTrue(counterA.greaterOrEqualThan(counterB));
    }

    function test_GreaterThan() public {
        counterA = SequenceCounter(100);
        counterB = SequenceCounter(42);
        assertTrue(counterA.greaterThan(counterB));
    }

    function test_EqualTo() public {
        counterA = SequenceCounter(42);
        counterB = SequenceCounter(42);
        assertTrue(counterA.equalTo(counterB));
    }
}
