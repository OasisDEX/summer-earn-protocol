// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {BaseArkParams} from "./Ark.sol";

// TODO
// Decide how to handle ark Params
// Refactor Ark's to be initialisable


/**
 * @custom:see IFleetCommanderFactory
 */
contract FleetCommanderFactory is ProtocolAccessManaged {
    address public immutable fleetCommanderImplementation;

    event FleetCommanderCreated(address indexed newFleetCommander);
    event ArkCreated(address indexed newArk);

    /**
     * @notice Configuration of an Ark added to the FleetCommander
     */
    struct NewArkConfig {
        BaseArkParams baseArkParams;
        bytes targetArkParams;
        address implementation; // Ark address
    }

    constructor(address _fleetCommanderImplementation_) {
        fleetCommanderImplementation = _fleetCommanderImplementation_;
    }

    function createFleetCommander(FleetCommanderParams memory params, NewArkConfig[] memory newArkConfigs) external onlyGovernor {
        // Clone FleetCommander
        address fleetCommanderClone = Clones.clone(fleetCommanderImplementation);
        FleetCommander(fleetCommanderClone).initialize(params);

        // Clone Arks
        for (uint256 i = 0; i < newArkConfigs.length; i++) {
            address arkClone = Clones.clone(newArkConfigs[i].implementation);

            (bool success, ) = arkClone.call(
                abi.encodeWithSignature("initialize((address,address,address,uint256),bytes)", newArkConfigs[i].baseArkParams, newArkConfigs[i].targetArkParams)
            );
            if (!success) {
                revert("Initialization failed");
            }

            emit ArkCreated(arkClone);

            Ark(arkClone).grantCommanderRole(fleetCommanderClone);
            FleetCommander(fleetCommanderClone).addArk(arkClone);
        }
    }
}