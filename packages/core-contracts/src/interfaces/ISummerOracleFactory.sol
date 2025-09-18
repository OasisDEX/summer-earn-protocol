// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerOracle} from "./ISummerOracle.sol";

interface ISummerOracleFactory {
    error InvalidHarborCommand();
    error FleetCommanderNotEnlisted(address fleet);

    event SummerOracleDeployed(
        address indexed fleet,
        address indexed summerOracle
    );

    function deploySummerOracle(
        address fleet
    ) external returns (ISummerOracle summerOracle);
}
