// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerOracle} from "./ISummerOracle.sol";

/**
 * @title ISummerOracleFactory
 * @notice Factory interface for deploying `SummerOracle` instances for FleetCommander vaults.
 *
 * @dev Security and invariants:
 * - The factory is constructed with a `HarborCommand` registry contract.
 * - `deploySummerOracle(fleet)` MUST revert unless `fleet` is enlisted (active) in HarborCommand.
 * - Deployments SHOULD be one-per-fleet. If an oracle already exists, implementations MAY revert with
 *   `SummerOracleAlreadyDeployed(fleet)`.
 *
 * Events:
 * - `SummerOracleDeployed(fleet, summerOracle)` emitted upon successful deployment and registration.
 */
interface ISummerOracleFactory {
    /**
     * @notice Error emitted when the provided HarborCommand address is zero or invalid.
     */
    error InvalidHarborCommand();

    /**
     * @notice Error emitted when attempting to deploy an oracle for a fleet not enlisted in HarborCommand.
     * @param fleet The FleetCommander address that failed enlistment verification
     */
    error FleetCommanderNotEnlisted(address fleet);

    /**
     * @notice Error emitted when attempting to deploy an oracle for a fleet that already has one.
     * @param fleet The FleetCommander address for which an oracle already exists
     */
    error SummerOracleAlreadyDeployed(address fleet);

    /**
     * @notice Emitted after a successful deployment of a `SummerOracle` for `fleet`.
     * @param fleet The FleetCommander address the oracle is bound to
     * @param summerOracle The deployed `SummerOracle` address
     */
    event SummerOracleDeployed(
        address indexed fleet,
        address indexed summerOracle
    );

    /**
     * @notice Deploys a new `SummerOracle` instance for the provided FleetCommander vault.
     * @dev Requirements:
     * - `fleet` MUST be enlisted in HarborCommand or the call reverts.
     * - Implementations MAY enforce single-oracle-per-fleet and revert if one already exists.
     *
     * Postconditions:
     * - A new `SummerOracle` is created, stored, and emitted via `SummerOracleDeployed`.
     *
     * @param fleet The FleetCommander (ERC4626) address this oracle will serve
     * @return summerOracle The deployed oracle instance implementing `ISummerOracle`
     */
    function deploySummerOracle(
        address fleet
    ) external returns (ISummerOracle summerOracle);
}
