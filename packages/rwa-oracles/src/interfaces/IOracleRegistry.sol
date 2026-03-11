// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOracleRegistryErrors} from "./IOracleRegistryErrors.sol";
import {IOracleRegistryEvents} from "./IOracleRegistryEvents.sol";

interface IOracleRegistry is IOracleRegistryErrors, IOracleRegistryEvents {
    function setOracle(
        string calldata ticker,
        address asset,
        address oracle
    ) external;

    function getOracleByTicker(
        string calldata ticker
    ) external view returns (address);

    function getOracleByAsset(address asset) external view returns (address);
}
