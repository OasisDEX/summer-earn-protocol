Here's a README for the MathUtils library:

# MathUtils Library

The MathUtils library provides advanced mathematical operations for Solidity smart contracts, with a
focus on high-precision calculations.

## Table of Contents

- [MathUtils Library](#mathutils-library)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Functions](#functions)
    - [rpow](#rpow)
  - [Usage](#usage)
  - [Security Considerations](#security-considerations)
  - [Gas Optimization](#gas-optimization)
  - [Testing](#testing)
  - [Contributing](#contributing)
  - [License](#license)

## Overview

The MathUtils library is designed to perform complex mathematical operations that are not natively
available in Solidity. It currently includes an optimized implementation of exponentiation with a
fractional base and integer exponent, which is particularly useful for financial calculations
involving compound interest or any scenario requiring precise power operations.

## Functions

### rpow

```solidity
function rpow(
    Percentage wrappedX,
    uint256 n,
    Percentage wrappedBase
) internal pure returns (Percentage z)
```

Calculates `x^n` with a precision of `base` (typically 1e18).

- `wrappedX`: The base number wrapped as a `Percentage`
- `n`: The exponent (integer)
- `wrappedBase`: The precision factor (typically 1e18) wrapped as a `Percentage`
- Returns: The result of `x^n`, representing `x^n * base` wrapped as a `Percentage`

This function uses an optimized assembly implementation for efficiency. It is equivalent to
`exp(ln(rate) * secondsSince)` and is derived from a similar function in MakerDAO's Pot.sol
contract.

## Usage

To use the MathUtils library in your Solidity contract:

1. Import the library:

```solidity
import { MathUtils } from 'path/to/MathUtils.sol';
import { Percentage, toPercentage } from '@summerfi/percentage-solidity/contracts/Percentage.sol';
```

2. Use the library functions:

```solidity
contract MyContract {
  using MathUtils for Percentage;

  function calculateCompoundInterest(
    uint256 principal,
    uint256 rate,
    uint256 time
  ) public pure returns (uint256) {
    Percentage wrappedRate = toPercentage(rate);
    Percentage wrappedBase = toPercentage(1e18);
    Percentage result = MathUtils.rpow(wrappedRate, time, wrappedBase);
    return (principal * Percentage.unwrap(result)) / 1e18;
  }
}
```

## Security Considerations

- The `rpow` function includes multiple checks to prevent overflow and ensure the validity of the
  calculations. However, it's important to use appropriate input values to avoid unexpected results.
- The function will revert if any intermediate calculation overflows, providing a safeguard against
  invalid results.

## Gas Optimization

The `rpow` function uses inline assembly for optimal gas efficiency. This implementation is
significantly more gas-efficient than naive Solidity implementations of power functions.

## Testing

Thorough testing of this library is crucial due to its complex nature and use of assembly. Ensure to
test with a wide range of inputs, including edge cases, to verify its correctness and robustness.

## Contributing

Contributions to improve the MathUtils library are welcome. Please ensure that any changes are
thoroughly tested and do not compromise the security or efficiency of the existing implementation.

## License

This library is released under the MIT License. See the SPDX-License-Identifier at the top of the
source file for details.
