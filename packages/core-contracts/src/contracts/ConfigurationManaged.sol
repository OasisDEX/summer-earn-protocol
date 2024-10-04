// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

/**
 * @title ConfigurationManaged
 * @notice Base contract for contracts that need to read from the ConfigurationManager
 * @dev This contract provides a standardized way for other contracts to access
 *      configuration values from the ConfigurationManager. It should be inherited
 *      by contracts that need to read these configurations.
 */
abstract contract ConfigurationManaged {
    IConfigurationManager public immutable configurationManager;

    /**
     * @notice Constructs the ConfigurationManaged contract
     * @param _configurationManager The address of the ConfigurationManager contract
     */
    constructor(address _configurationManager) {
        if (_configurationManager == address(0)) {
            revert ConfigurationManagerZeroAddress();
        }
        configurationManager = IConfigurationManager(_configurationManager);
    }

    /**
     * @notice Gets the address of the Raft contract
     * @return The address of the Raft contract
     */
    function raft() public view returns (address) {
        return configurationManager.raft();
    }

    /**
     * @notice Gets the address of the TipJar contract
     * @return The address of the TipJar contract
     */
    function tipJar() public view returns (address) {
        return configurationManager.tipJar();
    }

    /**
     * @notice Gets the address of the Treasury contract
     * @return The address of the Treasury contract
     */
    function treasury() public view returns (address) {
        return configurationManager.treasury();
    }

    // Add other configuration getter functions as needed
}

// Custom error
error ConfigurationManagerZeroAddress();
