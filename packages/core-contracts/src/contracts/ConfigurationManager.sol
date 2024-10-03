// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

import {ConfigurationManagerParams} from "../types/ConfigurationManagerTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title ConfigurationManager
 * @notice Manages system-wide configuration parameters for the protocol
 * @dev Implements the IConfigurationManager interface and inherits from ProtocolAccessManaged
 */
contract ConfigurationManager is IConfigurationManager, ProtocolAccessManaged {
    bool public initialized;
    /**
     * @notice The address of the Raft contract
     * @dev This is where rewards and farmed tokens are sent for processing
     */
    address public _raft;

    /**
     * @notice The address of the TipJar contract
     * @dev This is the contract that owns tips and is responsible for
     *      dispensing them to claimants
     */
    address public _tipJar;

    /**
     * @notice The address of the Treasury contract
     * @dev This is the contract that owns the treasury and is responsible for
     *      dispensing funds to the protocol's operations
     */
    address public _treasury;

    /**
     * @notice The address of theHarbor command
     * @dev This is the contract that's the registry of all Fleet Commanders
     */
    address public _harborCommand;

    /**
     * @notice Constructs the ConfigurationManager contract
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    function initialize(
        ConfigurationManagerParams memory params
    ) external onlyGovernor {
        if (initialized) {
            revert ConfigurationManagerAlreadyInitialized();
        }
        if (
            params.raft == address(0) ||
            params.tipJar == address(0) ||
            params.treasury == address(0) ||
            params.harborCommand == address(0)
        ) {
            revert AddressZero();
        }
        _raft = params.raft;
        _tipJar = params.tipJar;
        _treasury = params.treasury;
        _harborCommand = params.harborCommand;
        initialized = true;
    }

    /// @inheritdoc IConfigurationManager
    function raft() external view override returns (address) {
        if (_raft == address(0)) {
            revert RaftNotSet();
        }
        return _raft;
    }

    /// @inheritdoc IConfigurationManager
    function tipJar() external view override returns (address) {
        if (_tipJar == address(0)) {
            revert TipJarNotSet();
        }
        return _tipJar;
    }

    /// @inheritdoc IConfigurationManager
    function treasury() external view override returns (address) {
        if (_treasury == address(0)) {
            revert TreasuryNotSet();
        }
        return _treasury;
    }

    /// @inheritdoc IConfigurationManager
    function harborCommand() external view override returns (address) {
        if (_harborCommand == address(0)) {
            revert HarborCommandNotSet();
        }
        return _harborCommand;
    }

    /// @inheritdoc IConfigurationManager
    function setRaft(address newRaft) external onlyGovernor {
        _raft = newRaft;
        emit RaftUpdated(newRaft);
    }

    /// @inheritdoc IConfigurationManager
    function setTipJar(address newTipJar) external onlyGovernor {
        _tipJar = newTipJar;
        emit TipJarUpdated(newTipJar);
    }

    /// @inheritdoc IConfigurationManager
    function setTreasury(address newTreasury) external onlyGovernor {
        _treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /// @inheritdoc IConfigurationManager
    function setHarborCommand(address newHarborCommand) external onlyGovernor {
        _harborCommand = newHarborCommand;
        emit HarborCommandUpdated(newHarborCommand);
    }
}
