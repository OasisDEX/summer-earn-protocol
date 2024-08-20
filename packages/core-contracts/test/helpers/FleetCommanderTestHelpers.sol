// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";

/**
 * @title FleetCommanderTestHelpers
 * @dev A contract containing helper functions for FleetCommander tests
 * @notice This contract provides utility functions to simplify the creation of test data for FleetCommander tests
 */
contract FleetCommanderTestHelpers is Test {
    /**
     * @notice Generates a RebalanceData array with a single entry
     * @dev This function is used to create test data for rebalance operations
     * @param fromArk The address of the source Ark
     * @param toArk The address of the destination Ark
     * @param amount The amount of assets to be moved in the rebalance operation
     * @return RebalanceData[] An array containing a single RebalanceData struct
     */
    function generateRebalanceData(
        address fromArk,
        address toArk,
        uint256 amount
    ) internal pure returns (RebalanceData[] memory) {
        RebalanceData[] memory data = new RebalanceData[](1);
        data[0] = RebalanceData({
            fromArk: fromArk,
            toArk: toArk,
            amount: amount
        });
        return data;
    }

    function testSkipper() public {}
}
