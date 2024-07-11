// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {Ark, BaseArkParams} from "./Ark.sol";
import {FleetCommanderParams, FleetCommander} from "./FleetCommander.sol";
import {IFleetCommanderFactory, FactoryArkConfig} from "../interfaces/IFleetCommanderFactory.sol";

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

    constructor(address _fleetCommanderImplementation_) {
        fleetCommanderImplementation = _fleetCommanderImplementation_;
    }

    function createFleetCommander(
        FleetCommanderParams memory params,
        FactoryArkConfig[] memory arkFactoryConfigs
    ) external onlyGovernor {
        // Clone FleetCommander
        address fleetCommanderClone = Clones.clone(
            fleetCommanderImplementation
        );
        FleetCommander(fleetCommanderClone).initialize(params);

        // Clone Arks
        for (uint256 i = 0; i < arkFactoryConfigs.length; i++) {
            address arkClone = Clones.clone(
                arkFactoryConfigs[i].arkImplementation
            );

            (bool success, ) = arkClone.call(
                abi.encodeWithSignature(
                    "initialize((address,address,address,uint256),bytes)",
                    arkFactoryConfigs[i].baseArkParams,
                    arkFactoryConfigs[i].specificArkParams
                )
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
