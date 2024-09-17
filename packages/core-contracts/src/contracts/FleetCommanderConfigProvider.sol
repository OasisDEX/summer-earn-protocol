// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IArk} from "../interfaces/IArk.sol";

import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title FleetCommanderConfigProvider
 * @notice This contract provides configuration management for the FleetCommander
 */
contract FleetCommanderConfigProvider is
    IFleetCommanderConfigProvider,
    ProtocolAccessManaged
{
    FleetConfig public config;
    address[] public arks;
    mapping(address => bool) public isArkActive;
    mapping(address => bool) public isArkWithdrawable;

    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    function getArks() public view returns (address[] memory) {
        return arks;
    }

    function getConfig() external view override returns (FleetConfig memory) {
        return config;
    }
    // ARK MANAGEMENT

    function addArk(address ark) external onlyGovernor {
        _addArk(ark);
    }

    function addArks(address[] calldata _arkAddresses) external onlyGovernor {
        for (uint256 i = 0; i < _arkAddresses.length; i++) {
            _addArk(_arkAddresses[i]);
        }
    }

    function removeArk(address ark) external onlyGovernor {
        _removeArk(ark);
    }

    function setArkDepositCap(
        address ark,
        uint256 newDepositCap
    ) external onlyGovernor {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setDepositCap(newDepositCap);
    }

    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external onlyGovernor {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceOutflow(newMaxRebalanceOutflow);
    }

    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external onlyGovernor {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceInflow(newMaxRebalanceInflow);
    }

    // FLEET MANAGEMENT
    function setMinimumBufferBalance(
        uint256 newMinimumBalance
    ) external onlyGovernor {
        config.minimumBufferBalance = newMinimumBalance;
        emit FleetCommanderminimumBufferBalanceUpdated(newMinimumBalance);
    }

    function setFleetDepositCap(uint256 newCap) external onlyGovernor {
        config.depositCap = newCap;
        emit FleetCommanderDepositCapUpdated(newCap);
    }

    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external onlyGovernor {
        config.maxRebalanceOperations = newMaxRebalanceOperations;
        emit FleetCommanderMaxRebalanceOperationsUpdated(
            newMaxRebalanceOperations
        );
    }

    function setFleetConfig(FleetConfig memory _config) internal {
        config = _config;
    }

    // INTERNAL FUNCTIONS
    function _addArk(address ark) internal {
        if (ark == address(0)) {
            revert FleetCommanderInvalidArkAddress();
        }
        if (isArkActive[ark]) {
            revert FleetCommanderArkAlreadyExists(ark);
        }

        isArkActive[ark] = true;
        // Ark can be withdrawn by anyone if it doesnt' require keeper data
        isArkWithdrawable[ark] = !IArk(ark).requiresKeeperData();
        arks.push(ark);
        emit ArkAdded(ark);
    }

    function _removeArk(address ark) internal {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }

        for (uint256 i = 0; i < arks.length; i++) {
            if (arks[i] == ark) {
                _validateArkRemoval(ark);
                arks[i] = arks[arks.length - 1];
                arks.pop();
                break;
            }
        }

        isArkActive[ark] = false;
        emit ArkRemoved(ark);
    }

    function _validateArkRemoval(address ark) internal view {
        IArk _ark = IArk(ark);
        if (_ark.depositCap() > 0) {
            revert FleetCommanderArkDepositCapGreaterThanZero(ark);
        }
        if (_ark.totalAssets() != 0) {
            revert FleetCommanderArkAssetsNotZero(ark);
        }
    }
}
