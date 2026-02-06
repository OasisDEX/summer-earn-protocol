// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
    @notice Normalizes an amount from its original decimals to the target decimals
    @param amount The amount to normalize
    @param amountDecimals The number of decimals of the amount
    @param targetDecimals The target number of decimals

    @return The normalized amount
 */
function _normalizeAmount(
    uint256 amount,
    uint8 amountDecimals,
    uint8 targetDecimals
) pure returns (uint256) {
    if (amountDecimals > targetDecimals) {
        uint8 exp = amountDecimals - targetDecimals;
        return amount / (10 ** exp);
    } else if (amountDecimals < targetDecimals) {
        uint8 exp = targetDecimals - amountDecimals;
        return amount * (10 ** exp);
    } else {
        return amount;
    }
}
