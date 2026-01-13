// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TimelockGuard} from "./TimelockGuard.sol";

/**
 * @title TimelockGuardFactory
 * @notice Permissionless factory contract for creating TimelockGuard instances
 * @dev This factory allows anyone to deploy TimelockGuard contracts for use in governance timelock transactions.
 *      Each guard instance enforces a "not earlier than" timestamp constraint on permissionless actions.
 *
 * @custom:usage Governance proposals can use this factory to create guard instances that add an additional
 *              layer of protection to timelock transactions. The factory emits events that allow off-chain
 *              systems to track guard deployments and their associated minimum timestamps.
 *
 * @custom:security This factory is permissionless by design. Anyone can create guard instances, which is
 *                  intentional for governance use cases where transparency and verifiability are paramount.
 */
contract TimelockGuardFactory {
    /*//////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new TimelockGuard instance is created
     * @param guardAddress The address of the newly deployed TimelockGuard contract
     * @param minimumTimestamp The minimum timestamp (inclusive) set in the guard's constructor
     * @param creator The address that created the guard instance
     * @param blockTimestamp The block timestamp at which the guard was created
     * @dev This event allows off-chain systems to track guard deployments and their configuration.
     *      The `blockTimestamp` provides context about when the guard was created relative to its
     *      minimum timestamp requirement.
     */
    event TimelockGuardCreated(
        address indexed guardAddress,
        uint256 indexed minimumTimestamp,
        address indexed creator,
        uint256 blockTimestamp
    );

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new TimelockGuard instance with the specified minimum timestamp
     * @param _minimumTimestamp The earliest timestamp (inclusive) at which the guarded action can be executed
     *                          Must be a valid Unix timestamp (seconds since epoch)
     * @return guardAddress The address of the newly deployed TimelockGuard contract
     * @dev This function is permissionless - anyone can create guard instances. This is intentional
     *      for governance use cases where transparency and verifiability are important.
     *
     * @custom:example
     * ```solidity
     * // Create a guard that allows execution after January 1, 2025
     * uint256 minTimestamp = 1735689600; // Unix timestamp for 2025-01-01 00:00:00 UTC
     * address guard = factory.createTimelockGuard(minTimestamp);
     *
     * // Use the guard in a governance timelock transaction:
     * TimelockGuard(guard).validateTimestamp(); // Reverts if current time < minTimestamp
     * ```
     *
     * @custom:gas-considerations The gas cost is primarily determined by the contract deployment cost.
     *                            The TimelockGuard contract is minimal, so deployment is relatively cheap.
     */
    function createTimelockGuard(
        uint256 _minimumTimestamp
    ) public returns (address guardAddress) {
        // Deploy new TimelockGuard instance
        TimelockGuard guard = new TimelockGuard(_minimumTimestamp);
        guardAddress = address(guard);

        // Emit event with guard details
        emit TimelockGuardCreated(
            guardAddress,
            _minimumTimestamp,
            msg.sender,
            block.timestamp
        );
    }
}
