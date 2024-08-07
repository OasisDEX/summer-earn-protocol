// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {DeploymentScript} from "./common/DeploymentScript.s.sol";
import {ProtocolAccessManager} from "../src/contracts/ProtocolAccessManager.sol";
import {ConfigurationManager} from "../src/contracts/ConfigurationManager.sol";
import {Raft} from "../src/contracts/Raft.sol";
import {HarborCommand} from "../src/contracts/HarborCommand.sol";
import {ConfigurationManagerParams} from "../src/types/ConfigurationManagerTypes.sol";

/**
 * @title CoreDeploy
 * @notice Script for deploying core components of the protocol
 * @dev Inherits from DeploymentScript for common deployment functionality
 */
contract CoreDeploy is DeploymentScript {
    /**
     * @notice Runs the deployment script for core components
     * @dev Deploys ProtocolAccessManager, ConfigurationManager, and HarborCommand
     */
    function run() external reloadConfig {
        vm.createSelectFork(network);
        uint256 deployerPrivateKey = _getDeployerPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        if (config.governor == address(0)) {
            revert("Governor address not set");
        }
        if (config.swapProvider == address(0)) {
            revert("SwapProvider address not set");
        }
        if (config.tipJar == address(0)) {
            revert("TipJar address not set");
        }

        address protocolAccessManager = _deployProtocolAccessManager(
            config.governor
        );

        _deployRaft(config.swapProvider, protocolAccessManager);

        _deployConfigurationManager(
            protocolAccessManager,
            config.raft,
            config.tipJar
        );

        _deployHarborCommand(protocolAccessManager);

        vm.stopBroadcast();
    }

    /**
     * @notice Deploys the ProtocolAccessManager contract
     * @param _governor Address of the governor
     * @return Address of the deployed ProtocolAccessManager
     */
    function _deployProtocolAccessManager(
        address _governor
    ) internal returns (address) {
        if (config.protocolAccessManager != address(0)) {
            revert("ProtocolAccessManager already deployed");
        }
        ProtocolAccessManager protocolAccessManager = new ProtocolAccessManager(
            _governor
        );
        updateAddressInConfig(
            network,
            "protocolAccessManager",
            address(protocolAccessManager)
        );
        console.log(
            "Deployed Protocol Access Manager:",
            address(protocolAccessManager)
        );
        return address(protocolAccessManager);
    }

    /**
     * @notice Deploys the ConfigurationManager contract
     * @param _protocolAccessManager Address of the ProtocolAccessManager
     * @param _raft Address of the Raft contract
     * @param _tipJar Address of the TipJar contract
     * @return Address of the deployed ConfigurationManager
     */
    function _deployConfigurationManager(
        address _protocolAccessManager,
        address _raft,
        address _tipJar
    ) internal returns (address) {
        if (config.configurationManager != address(0)) {
            revert("ConfigurationManager already deployed");
        }
        ConfigurationManager configurationManager = new ConfigurationManager(
            ConfigurationManagerParams({
                accessManager: _protocolAccessManager,
                raft: _raft,
                tipJar: _tipJar
            })
        );
        updateAddressInConfig(
            network,
            "configurationManager",
            address(configurationManager)
        );
        console.log(
            "Deployed Configuration Manager:",
            address(configurationManager)
        );
        return address(configurationManager);
    }

    /**
     * @notice Deploys the HarborCommand contract
     * @param _protocolAccessManager Address of the ProtocolAccessManager
     * @return Address of the deployed HarborCommand
     */
    function _deployHarborCommand(
        address _protocolAccessManager
    ) internal returns (address) {
        if (config.harborCommand != address(0)) {
            revert("HarborCommand already deployed");
        }
        HarborCommand harborCommand = new HarborCommand(_protocolAccessManager);
        updateAddressInConfig(network, "harborCommand", address(harborCommand));
        console.log("Deployed Harbor Command:", address(harborCommand));

        return address(harborCommand);
    }

    /**
     * @notice Deploys the Raft contract
     * @param swapProvider Address of the SwapProvider
     * @param _protocolAccessManager Address of the ProtocolAccessManager
     * @return Address of the deployed Raft
     */
    function _deployRaft(
        address swapProvider,
        address _protocolAccessManager
    ) internal returns (address) {
        if (config.raft != address(0)) {
            revert("Raft already deployed");
        }
        Raft raft = new Raft(swapProvider, _protocolAccessManager);
        updateAddressInConfig(network, "raft", address(raft));
        console.log("Deployed Raft:", address(raft));

        return address(raft);
    }
}
