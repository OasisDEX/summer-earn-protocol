// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerOracle, IOracle, IPriceOracle} from "../interfaces/ISummerOracle.sol";
import {IPriceOracle} from "../interfaces/euler/IPriceOracle.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {SummerOracle} from "../contracts/SummerOracle.sol";
import {ISummerOracleFactory} from "../interfaces/ISummerOracleFactory.sol";

/// @title SummerOracle
/// @notice Oracle adapter that quotes between FleetCommander ERC4626 shares and its underlying asset.
/// @dev Implements Morpho's IOracle (single price scaled by 1e36) and Euler's / ERC-7726 IPriceOracle (quotes for fleet/quote).
contract SummerOracleFactory is ISummerOracleFactory {
    mapping(address fleet => ISummerOracle summerOracle) public summerOracles;

    IHarborCommand public immutable harborCommand;

    constructor(IHarborCommand _harborCommand) {
        if (address(_harborCommand) == address(0)) {
            revert InvalidHarborCommand();
        }
        harborCommand = _harborCommand;
    }

    function deploySummerOracle(
        address fleet
    ) external returns (ISummerOracle summerOracle) {
        if (!harborCommand.activeFleetCommanders(fleet)) {
            revert FleetCommanderNotEnlisted(fleet);
        }
        if (address(summerOracles[fleet]) != address(0)) {
            revert SummerOracleAlreadyDeployed(fleet);
        }
        summerOracle = new SummerOracle(fleet);
        summerOracles[fleet] = summerOracle;
        emit SummerOracleDeployed(fleet, address(summerOracle));
    }
}
