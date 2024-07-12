// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {Ark, BaseArkParams} from "./Ark.sol";
import {FleetCommanderParams, FleetCommander} from "./FleetCommander.sol";
import {IFleetCommanderFactory, FactoryArkConfig} from "../interfaces/IFleetCommanderFactory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../errors/FleetFactoryErrors.sol";

/**
 * @custom:see IFleetCommanderFactory
 */
contract FleetCommanderFactory is
    Initializable,
    IFleetCommanderFactory,
    ProtocolAccessManaged
{
    address public fleetCommanderImplementation;

    event FleetCommanderCreated(address indexed newFleetCommander);
    event ArkCreated(address indexed newArk);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _fleetCommanderImplementation_,
        address accessManager
    ) public initializer {
        fleetCommanderImplementation = _fleetCommanderImplementation_;
        __ProtocolAccessManaged_init(accessManager);
    }

    function createFleetCommander(
        FleetCommanderParams memory params,
        FactoryArkConfig[] memory arkFactoryConfigs
    ) external onlyGovernor returns (address) {
        // Clone FleetCommander
        address fleetCommanderClone = Clones.clone(
            fleetCommanderImplementation
        );
        FleetCommander(fleetCommanderClone).initialize(params);

        // Clone Arks
        address[] memory arkClones = new address[](arkFactoryConfigs.length);
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
                revert FleetCommanderInitializationFailed();
            }

            Ark(arkClone).grantCommanderRole(fleetCommanderClone);
            arkClones[i] = arkClone;

            emit ArkCreated(arkClone);
        }

        FleetCommander(fleetCommanderClone).addArks(arkClones);

        return address(fleetCommanderClone);
    }
}
