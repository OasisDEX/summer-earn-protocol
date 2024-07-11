// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

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
        bytes arkParams;
        address implementation; // Ark address
        uint256 maxAllocation; // Max allocation as token balance // Move this to params
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
            Ark(arkClone).initialize(newArkConfigs[i].arkParams);


            emit ArkCreated(arkClone);

            Ark(arkClone).grantCommanderRole(fleetCommanderClone);
            FleetCommander(fleetCommanderClone).addArk(arkClone);
        }
    }
}