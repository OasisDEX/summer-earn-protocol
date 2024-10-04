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

    function raft() external view override returns (address) {
        if (_raft == address(0)) {
            revert RaftNotSet();
        }
        return _raft;
    }

    function tipJar() external view override returns (address) {
        if (_tipJar == address(0)) {
            revert TipJarNotSet();
        }
        return _tipJar;
    }

    function treasury() external view override returns (address) {
        if (_treasury == address(0)) {
            revert TreasuryNotSet();
        }
        return _treasury;
    }

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
            params.treasury == address(0)
        ) {
            revert AddressZero();
        }
        _raft = params.raft;
        _tipJar = params.tipJar;
        _treasury = params.treasury;
        emit RaftUpdated(address(0), params.raft);
        emit TipJarUpdated(address(0), params.tipJar);
        emit TreasuryUpdated(address(0), params.treasury);
        initialized = true;
    }
    /**
     * @notice Sets a new address for the Raft contract
     * @param newRaft The new address for the Raft contract
     * @dev Can only be called by the governor
     * @dev Emits a RaftUpdated event
     */

    function setRaft(address newRaft) external onlyGovernor {
        emit RaftUpdated(_raft, newRaft);
        _raft = newRaft;
    }

    /**
     * @notice Sets a new address for the TipJar contract
     * @param newTipJar The new address for the TipJar contract
     * @dev Can only be called by the governor
     * @dev Emits a TipJarUpdated event
     */
    function setTipJar(address newTipJar) external onlyGovernor {
        emit TipJarUpdated(_tipJar, newTipJar);
        _tipJar = newTipJar;
    }

    /**
     * @notice Sets a new address for the Treasury contract
     * @param newTreasury The new address for the Treasury contract
     * @dev Can only be called by the governor
     * @dev Emits a TreasuryUpdated event
     */
    function setTreasury(address newTreasury) external onlyGovernor {
        emit TreasuryUpdated(_treasury, newTreasury);
        _treasury = newTreasury;
    }
}
