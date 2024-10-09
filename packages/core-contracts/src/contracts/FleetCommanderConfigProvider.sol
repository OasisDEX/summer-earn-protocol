// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IArk} from "../interfaces/IArk.sol";
import {FleetCommanderParams} from "../types/FleetCommanderTypes.sol";
import {FleetCommanderPausable} from "./FleetCommanderPausable.sol";

import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";

import {ContractSpecificRoles, IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {ArkParams, BufferArk} from "./arks/BufferArk.sol";

/**
 * @title
 * @author SummerFi
 * @notice This contract provides configuration management for the FleetCommander
 * @custom:see IFleetCommanderConfigProvider
 */
contract FleetCommanderConfigProvider is
    ProtocolAccessManaged,
    FleetCommanderPausable,
    IFleetCommanderConfigProvider
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

    ///@inheritdoc IFleetCommanderConfigProvider
    function getArks() public view returns (address[] memory) {
        return arks;
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function getConfig() external view override returns (FleetConfig memory) {
        return config;
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function bufferArk() external view returns (address) {
        return address(config.bufferArk);
    }

    // ARK MANAGEMENT

    ///@inheritdoc IFleetCommanderConfigProvider
    function addArk(address ark) external onlyGovernor whenNotPaused {
        _addArk(ark);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function addArks(
        address[] calldata _arkAddresses
    ) external onlyGovernor whenNotPaused {
        for (uint256 i = 0; i < _arkAddresses.length; i++) {
            _addArk(_arkAddresses[i]);
        }
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function removeArk(address ark) external onlyGovernor whenNotPaused {
        _removeArk(ark);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function setArkDepositCap(
        address ark,
        uint256 newDepositCap
    ) external onlyCurator whenNotPaused {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setDepositCap(newDepositCap);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function setArkMaxRebalanceOutflow(
        address ark,
        uint256 newMaxRebalanceOutflow
    ) external onlyCurator whenNotPaused {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceOutflow(newMaxRebalanceOutflow);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function setArkMaxRebalanceInflow(
        address ark,
        uint256 newMaxRebalanceInflow
    ) external onlyCurator whenNotPaused {
        if (!isArkActive[ark]) {
            revert FleetCommanderArkNotFound(ark);
        }
        IArk(ark).setMaxRebalanceInflow(newMaxRebalanceInflow);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function setMinimumBufferBalance(
        uint256 newMinimumBalance
    ) external onlyCurator whenNotPaused {
        config.minimumBufferBalance = newMinimumBalance;
        emit FleetCommanderminimumBufferBalanceUpdated(newMinimumBalance);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function setFleetDepositCap(
        uint256 newCap
    ) external onlyCurator whenNotPaused {
        config.depositCap = newCap;
        emit FleetCommanderDepositCapUpdated(newCap);
    }

    ///@inheritdoc IFleetCommanderConfigProvider
    function setMaxRebalanceOperations(
        uint256 newMaxRebalanceOperations
    ) external onlyCurator whenNotPaused {
        config.maxRebalanceOperations = newMaxRebalanceOperations;
        emit FleetCommanderMaxRebalanceOperationsUpdated(
            newMaxRebalanceOperations
        );
    }

    // INTERNAL FUNCTIONS
    /**
     * @dev Internal function to set the fleet configuration
     * @param _config The new FleetConfig to be set
     * @custom:internal-logic
     * - Directly assigns the provided _config to the config state variable
     * @custom:effects
     * - Updates the global fleet configuration
     * @custom:security-considerations
     * - This function can significantly alter the behavior of the fleet
     * - Should only be called by trusted functions with proper access control
     */
    function _setFleetConfig(FleetConfig memory _config) internal {
        config = _config;
    }

    /**
     * @dev Internal function to add a new Ark to the fleet
     * @param ark The address of the Ark to be added
     * @custom:internal-logic
     * - Checks if the ark address is valid (not zero)
     * - Verifies the ark is not already active
     * - Sets the ark as active and determines its withdrawability
     * - Checks if the ark already has a commander
     * - Registers this contract as the ark's FleetCommander
     * - Adds the ark to the list of active arks
     * @custom:effects
     * - Modifies isArkActive and isArkWithdrawable mappings
     * - Updates the arks array
     * - Emits an ArkAdded event
     * @custom:security-considerations
     * - Ensures no duplicate arks are added
     * - Prevents adding arks that already have a commander
     * - Only callable internally, typically by privileged roles
     */
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

    /**
     * @dev Internal function to remove an Ark from the fleet
     * @param ark The address of the Ark to be removed
     * @custom:internal-logic
     * - Checks if the ark is currently active
     * - Locates and removes the ark from the active arks list
     * - Validates that the ark can be safely removed
     * - Marks the ark as inactive
     * - Unregisters this contract as the ark's FleetCommander
     * - Revokes the COMMANDER_ROLE for this contract on the ark
     * @custom:effects
     * - Modifies the isArkActive mapping
     * - Updates the arks array
     * - Changes the ark's FleetCommander status
     * - Revokes a role in the access manager
     * - Emits an ArkRemoved event
     * @custom:security-considerations
     * - Ensures only active arks can be removed
     * - Validates ark state before removal to prevent inconsistencies
     * - Only callable internally, typically by privileged roles
     */
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

    /**
     * @dev Internal function to validate if an Ark can be safely removed
     * @param ark The address of the Ark to be validated for removal
     * @custom:internal-logic
     * - Checks if the ark's deposit cap is zero
     * - Verifies that the ark holds no assets
     * @custom:effects
     * - No direct state changes, but may revert the transaction
     * @custom:security-considerations
     * - Prevents removal of arks with non-zero deposit caps or assets
     * - Ensures arks are in a safe state before removal
     * - Critical for maintaining the integrity of the fleet
     */
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
