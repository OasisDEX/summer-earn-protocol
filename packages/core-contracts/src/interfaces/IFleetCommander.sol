// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderParams, ArkConfiguration, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IFleetCommanderEvents} from "../events/IFleetCommanderEvents.sol";

/// @title IFleetCommander Interface
/// @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
interface IFleetCommander is IFleetCommanderEvents, IERC4626 {
    /**
     * @notice Retrieves the ark configuration for a given ark address
     * @param arkAddress The address of the ark
     * @return The ArkConfiguration struct for the specified ark
     */
    function arks(
        address arkAddress
    ) external view returns (ArkConfiguration memory);

    /* FUNCTIONS - PUBLIC - USER */
    /**
     * @notice Withdraws assets from the FleetCommander
     * @param assets The amount of assets to withdraw
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the assets
     * @return The amount of assets withdrawn
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external override returns (uint256);

    /**
     * @notice Forces a withdrawal of assets from the FleetCommander
     * @param assets The amount of assets to forcefully withdraw
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the assets
     * @return The amount of assets forcefully withdrawn
     */
    function forceWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);

    /**
     * @notice Deposits assets into the FleetCommander
     * @param assets The amount of assets to deposit
     * @param receiver The address that will receive the shares
     * @return The amount of shares minted
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external override returns (uint256);

    function tip() external returns (uint256);

    /* FUNCTIONS - EXTERNAL - KEEPER */
    /**
     * @notice Rebalances the assets across Arks
     * @param data Array of typed rebalance data struct
     */
    function rebalance(RebalanceData[] calldata data) external;

    /**
     * @notice Adjusts the buffer of funds
     * @param data Array of typed rebalance data struct (fleet commander address used as fromArk)
     */
    function adjustBuffer(RebalanceData[] calldata data) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */
    /**
     * @notice Sets a new deposit cap
     * @param newCap The new deposit cap value
     */
    function setDepositCap(uint256 newCap) external;

    /**
     * @notice Sets a new tip jar address
     * @param newTipJar The new fee address
     */
    function setTipJar(address newTipJar) external;

    /**
     * @notice Sets a new tip rate
     * @param newTipRate The new tip rate for the fleet
     */
    function setTipRate(uint256 newTipRate) external;

    /**
     * @notice Adds a new Ark
     * @param ark The address of the new Ark
     * @param maxAllocation The maximum allocation for the new Ark
     */
    function addArk(address ark, uint256 maxAllocation) external;

    /**
     * @notice Removes an existing Ark
     * @param ark The address of the Ark to remove
     */
    function removeArk(address ark) external;

    /**
     * @notice Sets a new maximum allocation for an Ark
     * @param ark The address of the Ark
     * @param newMaxAllocation The new maximum allocation
     */
    function setMaxAllocation(address ark, uint256 newMaxAllocation) external;

    /**
     * @notice Updates the rebalance cooldown period
     * @param newCooldown The new cooldown period in seconds
     */
    function updateRebalanceCooldown(uint256 newCooldown) external;

    /**
     * @notice Forces a rebalance operation
     * @param data Array of typed rebalance data struct
     *
     * @dev has no cooldown enforced but only callable by privileged role
     */
    function forceRebalance(RebalanceData[] calldata data) external;

    /**
     * @notice Initiates an emergency shutdown of the FleetCommander
     */
    function emergencyShutdown() external;
}
