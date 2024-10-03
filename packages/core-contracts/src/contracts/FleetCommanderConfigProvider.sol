// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IArk} from "../interfaces/IArk.sol";
import {FleetCommanderParams} from "../types/FleetCommanderTypes.sol";

import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";

import {ContractSpecificRoles, IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ArkParams, BufferArk} from "./arks/BufferArk.sol";
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

    uint256 public constant MAX_REBALANCE_OPERATIONS = 10;

    constructor(
        FleetCommanderParams memory params
    ) ProtocolAccessManaged(params.accessManager) {
        BufferArk _bufferArk = new BufferArk(
            ArkParams({
                name: "BufferArk",
                accessManager: address(params.accessManager),
                token: params.asset,
                configurationManager: address(params.configurationManager),
                depositCap: type(uint256).max,
                maxRebalanceOutflow: type(uint256).max,
                maxRebalanceInflow: type(uint256).max,
                requiresKeeperData: false
            }),
            address(this)
        );
        _setFleetConfig(
            FleetConfig({
                bufferArk: IArk(address(_bufferArk)),
                minimumBufferBalance: params.initialMinimumBufferBalance,
                depositCap: params.depositCap,
                maxRebalanceOperations: MAX_REBALANCE_OPERATIONS
            })
        );
        isArkActive[address(_bufferArk)] = true;
        isArkWithdrawable[address(_bufferArk)] = true;
    }

    function getArks() public view returns (address[] memory) {
        return arks;
    }

    function getConfig() external view override returns (FleetConfig memory) {
        return config;
    }

    function bufferArk() external view returns (address) {
        return address(config.bufferArk);
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
    ) external onlyCurator {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setDepositCap(newDepositCap);
    }

    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external onlyCurator {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceOutflow(newMaxRebalanceOutflow);
    }

    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external onlyCurator {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceInflow(newMaxRebalanceInflow);
    }

    // FLEET MANAGEMENT
    function setMinimumBufferBalance(
        uint256 newMinimumBalance
    ) external onlyCurator {
        config.minimumBufferBalance = newMinimumBalance;
        emit FleetCommanderminimumBufferBalanceUpdated(newMinimumBalance);
    }

    function setFleetDepositCap(uint256 newCap) external onlyCurator {
        config.depositCap = newCap;
        emit FleetCommanderDepositCapUpdated(newCap);
    }

    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external onlyCurator {
        config.maxRebalanceOperations = newMaxRebalanceOperations;
        emit FleetCommanderMaxRebalanceOperationsUpdated(
            newMaxRebalanceOperations
        );
    }

    // INTERNAL FUNCTIONS
    function _setFleetConfig(FleetConfig memory _config) internal {
        config = _config;
    }

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
        if (IArk(ark).getConfig().commander != address(0)) {
            revert FleetCommanderArkAlreadyHasCommander();
        }
        IArk(ark).registerFleetCommander();
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
        IArk(ark).unregisterFleetCommander();
        _accessManager.selfRevokeContractSpecificRole(
            ContractSpecificRoles.COMMANDER_ROLE,
            address(ark)
        );
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
