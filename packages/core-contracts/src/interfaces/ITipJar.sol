// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ITipJarEvents} from "./ITipJarEvents.sol";
import "../types/Percentage.sol";

/**
 * @title ITipJar
 * @notice Interface for the TipJar contract
 */
interface ITipJar is ITipJarEvents {
    struct TipStream {
        address recipient;
        Percentage allocation;
        uint256 minimumTerm;
    }

    function addTipStream(address recipient, Percentage allocation, uint256 minimumTerm) external;
    function removeTipStream(address recipient) external;
    function updateTipStream(address recipient, Percentage newAllocation, uint256 newMinimumTerm) external;
    function getTipStream(address recipient) external view returns (TipStream memory);
    function getAllTipStreams() external view returns (TipStream[] memory);
    function shake(IERC4626 fleetCommander) external;
    function shakeMultiple(IERC4626[] calldata fleetCommanders) external;
}