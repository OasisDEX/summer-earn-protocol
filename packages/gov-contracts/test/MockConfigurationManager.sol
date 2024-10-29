// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IConfigurationManager} from "@summerfi/protocol-interfaces/IConfigurationManager.sol";
import {ConfigurationManagerParams} from "@summerfi/protocol-interfaces/ConfigurationManagerTypes.sol";

contract MockConfigurationManager is IConfigurationManager {
    address public governor;

    function setGovernor(address _governor) external {
        governor = _governor;
    }

    function getGovernor() external view returns (address) {
        return governor;
    }

    // All other functions revert
    function initializeConfiguration(
        ConfigurationManagerParams memory
    ) external pure {
        revert("Not implemented");
    }

    function raft() external pure returns (address) {
        revert("Not implemented");
    }

    function tipJar() external pure returns (address) {
        revert("Not implemented");
    }

    function treasury() external pure returns (address) {
        revert("Not implemented");
    }

    function harborCommand() external pure returns (address) {
        revert("Not implemented");
    }

    function setRaft(address) external pure {
        revert("Not implemented");
    }

    function setTipJar(address) external pure {
        revert("Not implemented");
    }

    function setTreasury(address) external pure {
        revert("Not implemented");
    }

    function setHarborCommand(address) external pure {
        revert("Not implemented");
    }
}
