// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Token Library
 * @author halaprix
 * @notice This library provides utility functions for handling token decimals and conversions
 * @dev Implements functions to get token decimals and convert amounts between different decimal representations
 */
library TokenLibrary {
    /**
     * @notice Retrieves the number of decimals for a given token
     * @dev Uses a low-level call to get the decimals, defaulting to 18 if the call fails
     * @param token The ERC20 token to query
     * @return The number of decimals for the token
     *
     * @dev Process:
     * 1. Attempts to call the 'decimals()' function on the token contract
     * 2. If the call succeeds, decodes and returns the result
     * 3. If the call fails, returns 18 as a default value
     *
     * @dev Note: This function assumes that tokens follow the ERC20 standard.
     * Non-standard tokens may cause unexpected behavior.
     */
    function getDecimals(IERC20 token) internal view returns (uint8) {
        (bool success, bytes memory data) = address(token).staticcall(
            abi.encodeWithSignature("decimals()")
        );

        // If the call was successful and returned data
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }

        // If the call was successful but returned no data, or if the call failed
        return 18;
    }

    /**
     * @notice Converts an amount from its original decimal representation to 18 decimals (wei)
     * @dev Adjusts the amount based on the difference between the original decimals and 18
     * @param amount The amount to convert
     * @param decimals The original number of decimals
     * @return The amount converted to 18 decimal representation
     *
     * @dev Calculation:
     * - If decimals == 18, no conversion needed
     * - If decimals > 18, divide by 10^(decimals - 18)
     * - If decimals < 18, multiply by 10^(18 - decimals)
     *
     * @dev Note: This function assumes that the input amount is in its original decimal representation.
     * Incorrect input decimals will lead to incorrect conversions.
     */
    function toWei(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount / (10 ** (decimals - 18));
        return amount * (10 ** (18 - decimals));
    }

    /**
     * @notice Converts an amount from 18 decimals (wei) to a specified decimal representation
     * @dev Adjusts the amount based on the difference between 18 and the target decimals
     * @param amount The amount in 18 decimal representation to convert
     * @param decimals The target number of decimals
     * @return The amount converted to the specified decimal representation
     *
     * @dev Calculation:
     * - If decimals == 18, no conversion needed
     * - If decimals > 18, multiply by 10^(decimals - 18)
     * - If decimals < 18, divide by 10^(18 - decimals)
     *
     * @dev Note: This function assumes that the input amount is in 18 decimal representation.
     * Incorrect input amounts will lead to incorrect conversions.
     */
    function fromWei(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount * (10 ** (decimals - 18));
        return amount / (10 ** (18 - decimals));
    }

    /**
     * @notice Converts an amount from one decimal representation to another
     * @dev Performs the conversion directly to avoid precision loss
     * @param amount The amount to convert
     * @param fromDecimals The original number of decimals
     * @param toDecimals The target number of decimals
     * @return The amount converted to the target decimal representation
     *
     * @dev Process:
     * 1. If fromDecimals == toDecimals, no conversion needed
     * 2. If fromDecimals < toDecimals, multiply by 10^(toDecimals - fromDecimals)
     * 3. If fromDecimals > toDecimals, divide by 10^(fromDecimals - toDecimals)
     *
     * @dev Note: This function provides a more precise way to convert between any two decimal representations.
     * It avoids the intermediate step of converting to 18 decimals, which can cause precision loss.
     */
    function convertDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals == toDecimals) return amount;

        if (fromDecimals < toDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        } else {
            return amount / (10 ** (fromDecimals - toDecimals));
        }
    }
}
