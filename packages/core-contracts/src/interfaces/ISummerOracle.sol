// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IOracle} from "./morpho/IOracle.sol";
import {IPriceOracle} from "./euler/IPriceOracle.sol";

interface ISummerOracle is IOracle, IPriceOracle {
    error UnsupportedPair(address fleet, address quote);
    error InvalidFleet();
    error InvalidAsset();
    error InvalidDecimals();

    function getRate() external view returns (uint256);
}
