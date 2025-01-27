// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHarborCommandEvents} from "../events/IHarborCommandEvents.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title HarborCommand - Fleet Commander Management System
 * @dev This contract serves as a central registry for managing official Fleet Commanders in the system.
 *
 * The HarborCommand contract is responsible for:
 * 1. Maintaining a list of authorized Fleet Commanders.
 * 2. Providing functions to enlist new Fleet Commanders and decommission existing ones.
 * 3. Offering a way to verify the active status of Fleet Commanders.
 * 4. Ensuring that only authorized entities (Governors) can modify the Fleet Commander roster.
 *
 * Key features:
 * - Enlistment and decommissioning of Fleet Commanders with proper access control.
 * - Prevention of duplicate enlistments and erroneous decommissions.
 * - Efficient storage and retrieval of active Fleet Commanders.
 * - Event emission for transparent tracking of roster changes.
 *
 * This contract plays a crucial role in maintaining the integrity and security of the fleet management system
 * by providing a reliable source of truth for official fleet verification.
 * @custom:see IHarborCommand
 */
contract HarborCommand is
    ProtocolAccessManaged,
    IHarborCommandEvents,
    IHarborCommand
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Set of active Fleet Commander addresses
    EnumerableSet.AddressSet private _activeFleetCommanders;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the HarborCommand contract
     * @param _accessManager Address of the access manager contract
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHarborCommand
    function enlistFleetCommander(
        address _fleetCommander
    ) external onlyGovernor {
        if (!_activeFleetCommanders.add(_fleetCommander)) {
            revert FleetCommanderAlreadyEnlisted(_fleetCommander);
        }
        emit FleetCommanderEnlisted(_fleetCommander);
    }

    /// @inheritdoc IHarborCommand
    function decommissionFleetCommander(
        address _fleetCommander
    ) external onlyGovernor {
        if (!_activeFleetCommanders.remove(_fleetCommander)) {
            revert FleetCommanderNotEnlisted(_fleetCommander);
        }
        emit FleetCommanderDecommissioned(_fleetCommander);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHarborCommand
    function getActiveFleetCommanders()
        external
        view
        override
        returns (address[] memory)
    {
        return _activeFleetCommanders.values();
    }

    /// @inheritdoc IHarborCommand
    function activeFleetCommanders(
        address _fleetCommander
    ) external view returns (bool) {
        return _activeFleetCommanders.contains(_fleetCommander);
    }

    /// @inheritdoc IHarborCommand
    function fleetCommandersList(
        uint256 index
    ) external view returns (address) {
        return _activeFleetCommanders.at(index);
    }
}
