// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
/**
 * @title FleetCommanderTestHelpers
 * @dev A contract containing helper functions for FleetCommander tests
 * @notice This contract provides utility functions to simplify the creation of test data for FleetCommander tests
 */

contract FleetCommanderTestHelpers {
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
            amount: amount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        return data;
    }

    /**
     * @dev Generates an array of `RebalanceData` structs for rebalancing.
     * @param fromArk The address of the source Ark.
     * @param toArk The address of the destination Ark.
     * @param amount The amount to be rebalanced.
     * @param boardData Additional data for boarding the Ark.
     * @param disembarkData Additional data for disembarking the Ark.
     * @return An array of `RebalanceData` structs containing the rebalance information.
     */
    function generateRebalanceData(
        address fromArk,
        address toArk,
        uint256 amount,
        bytes memory boardData,
        bytes memory disembarkData
    ) internal pure returns (RebalanceData[] memory) {
        RebalanceData[] memory data = new RebalanceData[](1);
        data[0] = RebalanceData({
            fromArk: fromArk,
            toArk: toArk,
            amount: amount,
            boardData: boardData,
            disembarkData: disembarkData
        });
        return data;
    }

    function testSkipper() public {}
}
