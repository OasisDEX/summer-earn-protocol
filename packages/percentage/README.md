# Percentage and PercentageUtils Libraries

This README provides an overview and usage guide for the `Percentage` and `PercentageUtils` libraries, which offer a custom type and utility functions for working with percentage values in Solidity smart contracts.

## Table of Contents

- [Percentage and PercentageUtils Libraries](#percentage-and-percentageutils-libraries)
  - [Table of Contents](#table-of-contents)
  - [Percentage Library](#percentage-library)
    - [Features](#features)
    - [Key Functions](#key-functions)
  - [PercentageUtils Library](#percentageutils-library)
    - [Key Functions](#key-functions-1)
  - [Usage Examples](#usage-examples)
  - [Constants](#constants)
  - [Best Practices](#best-practices)

## Percentage Library

The `Percentage` library introduces a custom type for handling percentage values with high precision.

### Features

- Custom `Percentage` type based on `uint256`
- Overloaded operators for arithmetic and comparison operations
- Constants for percentage-related calculations

### Key Functions

- `toPercentage(uint256 value) -> Percentage`: Converts a uint256 to a Percentage
- `fromPercentage(Percentage value) -> uint256`: Converts a Percentage to a uint256

## PercentageUtils Library

The `PercentageUtils` library provides utility functions for applying percentages to amounts and performing percentage-related calculations.

### Key Functions

- `addPercentage(uint256 amount, Percentage percentage) -> uint256`
- `subtractPercentage(uint256 amount, Percentage percentage) -> uint256`
- `applyPercentage(uint256 amount, Percentage percentage) -> uint256`
- `isPercentageInRange(Percentage percentage) -> bool`
- `fromFraction(uint256 numerator, uint256 denominator) -> Percentage`
- `fromIntegerPercentage(uint256 percentage) -> Percentage`

## Usage Examples

```solidity
// Import the libraries
import {Percentage, PERCENTAGE_FACTOR} from "./Percentage.sol";
import {PercentageUtils} from "./PercentageUtils.sol";

contract ExampleContract {
    function exampleUsage() public pure returns (uint256) {
        // Create a Percentage (50%)
        Percentage fiftyPercent = PercentageUtils.fromIntegerPercentage(50);
        // or Percentage.wrap(50 * PERCENTAGE_FACTOR)

        // Apply the percentage to an amount
        uint256 amount = 1000;
        uint256 result = PercentageUtils.applyPercentage(amount, fiftyPercent);
        
        // result will be 500
        return result;
    }

    function exampleAddition() public pure returns (Percentage) {
        Percentage a = Percentage.wrap(25 * PERCENTAGE_FACTOR); // 25%
        Percentage b = Percentage.wrap(30 * PERCENTAGE_FACTOR); // 30%
        
        // Using overloaded + operator
        return a + b; // Returns 55%
    }

    function exampleConversion() public pure returns (Percentage) {
        // Convert from fraction to Percentage
        return PercentageUtils.fromFraction(1, 4); // Returns 25%
    }
}
```

## Constants

- `PERCENTAGE_DECIMALS`: The number of decimal places used for percentage calculations (18)
- `PERCENTAGE_FACTOR`: The scaling factor for percentages (10^18)
- `PERCENTAGE_100`: Represents 100% as a Percentage type

## Best Practices

1. Always use the `Percentage` type for percentage values to ensure consistency and avoid errors.
2. Use `PercentageUtils` functions for applying percentages to amounts to handle scaling correctly.
3. When converting between `uint256` and `Percentage`, always use the provided conversion functions to maintain precision.
4. Check if a percentage is in range using `isPercentageInRange()` before performing critical operations.
5. Remember that percentage operations may result in rounding errors due to integer division. Consider adding safety margins where necessary.

By following these guidelines and utilizing the provided libraries, you can safely and efficiently work with percentages in your Solidity smart contracts.