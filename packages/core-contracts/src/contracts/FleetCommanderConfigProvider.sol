// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IArk} from "../interfaces/IArk.sol";
import {FleetCommanderParams} from "../types/FleetCommanderTypes.sol";
import {FleetCommanderPausable} from "./FleetCommanderPausable.sol";

import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title FleetCommanderConfigProvider
 * @notice This contract provides configuration management for the FleetCommander
 */
contract FleetCommanderConfigProvider is
    FleetCommanderPausable,
    IFleetCommanderConfigProvider,
    ProtocolAccessManaged
{
    FleetConfig public config;
    address[] public arks;
    mapping(address => bool) public isArkActive;
    mapping(address => bool) public isArkWithdrawable;

    uint256 public constant MAX_REBALANCE_OPERATIONS = 10;
    uint256 public constant INITIAL_MINIMUM_PAUSE_TIME = 36 hours;

    constructor(
        FleetCommanderParams memory params
    )
        ProtocolAccessManaged(params.accessManager)
        FleetCommanderPausable(INITIAL_MINIMUM_PAUSE_TIME)
    {
        _setFleetConfig(
            FleetConfig({
                bufferArk: IArk(params.bufferArk),
                minimumBufferBalance: params.initialMinimumBufferBalance,
                depositCap: params.depositCap,
                maxRebalanceOperations: MAX_REBALANCE_OPERATIONS
            })
        );
        isArkActive[address(config.bufferArk)] = true;
        isArkWithdrawable[address(config.bufferArk)] = true;

        _setupArks(params.initialArks);
    }

    function getArks() public view returns (address[] memory) {
        return arks;
    }

    function getConfig() external view override returns (FleetConfig memory) {
        return config;
    }
    // ARK MANAGEMENT

    function addArk(address ark) external onlyGovernor whenNotPaused {
        _addArk(ark);
    }

    function addArks(
        address[] calldata _arkAddresses
    ) external onlyGovernor whenNotPaused {
        for (uint256 i = 0; i < _arkAddresses.length; i++) {
            _addArk(_arkAddresses[i]);
        }
    }

    function removeArk(address ark) external onlyGovernor whenNotPaused {
        _removeArk(ark);
    }

    function setArkDepositCap(
        address ark,
        uint256 newDepositCap
    ) external onlyGovernor whenNotPaused {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setDepositCap(newDepositCap);
    }

    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external onlyGovernor whenNotPaused {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceOutflow(newMaxRebalanceOutflow);
    }

    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external onlyGovernor whenNotPaused {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceInflow(newMaxRebalanceInflow);
    }

    function setMinimumBufferBalance(
        uint256 newMinimumBalance
    ) external onlyGovernor whenNotPaused {
        config.minimumBufferBalance = newMinimumBalance;
        emit FleetCommanderminimumBufferBalanceUpdated(newMinimumBalance);
    }

    function setFleetDepositCap(
        uint256 newCap
    ) external onlyGovernor whenNotPaused {
        config.depositCap = newCap;
        emit FleetCommanderDepositCapUpdated(newCap);
    }

    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external onlyGovernor whenNotPaused {
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

    function _setupArks(address[] memory _arkAddresses) internal {
        for (uint256 i = 0; i < _arkAddresses.length; i++) {
            _addArk(_arkAddresses[i]);
        }
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
