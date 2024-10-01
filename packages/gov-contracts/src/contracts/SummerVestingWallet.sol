// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

/**
 * @title SummerVestingWallet
 * @dev Extension of OpenZeppelin's VestingWallet with custom vesting schedules.
 * Supports two types of vesting: 6-month cliff with full unlock, and 2-year vesting with quarterly unlocks.
 */

contract SummerVestingWallet is VestingWallet {
    /// @dev Duration of a quarter in seconds
    uint256 private constant QUARTER = 91 days;

    /// @dev Enum representing the types of vesting schedules
    enum VestingType {
        SixMonthCliff,
        TwoYearQuarterly
    }

    /// @dev The type of vesting schedule for this wallet
    VestingType private immutable _vestingType;

    /**
     * @dev Constructor that sets up the vesting wallet with a specific vesting type
     * @param beneficiaryAddress Address of the beneficiary to whom vested tokens are transferred
     * @param startTimestamp Unix timestamp marking the start of the vesting period
     * @param durationSeconds Duration of the vesting period in seconds
     * @param vestingType Type of vesting schedule (0 for SixMonthCliff, 1 for TwoYearQuarterly)
     */
    constructor(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        VestingType vestingType
    ) VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds) {
        _vestingType = VestingType(vestingType);
    }

    /**
     * @dev Calculates the amount of tokens that has vested at a specific time
     * @param totalAllocation Total number of tokens allocated for vesting
     * @param timestamp The timestamp to check for vested tokens
     * @return The amount of tokens already vested
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            if (_vestingType == VestingType.SixMonthCliff) {
                // 6 months cliff, then full unlock
                return timestamp >= start() + 180 days ? totalAllocation : 0;
            } else {
                // 2 years total with quarterly unlocks
                uint256 elapsedQuarters = (timestamp - start()) / QUARTER;
                return (totalAllocation * elapsedQuarters) / 8;
            }
        }
    }

    /**
     * @dev Returns the type of vesting schedule for this wallet
     * @return The vesting type (SixMonthCliff or TwoYearQuarterly)
     */
    function getVestingType() public view returns (VestingType) {
        return _vestingType;
    }
}
