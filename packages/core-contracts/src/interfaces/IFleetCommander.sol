// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderParams, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IFleetCommanderEvents} from "../events/IFleetCommanderEvents.sol";

/// @title IFleetCommander Interface
/// @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
interface IFleetCommander is IFleetCommanderEvents, IERC4626 {
    /**
     * @notice Retrieves the arks currently linked to fleet
     * @return An array of linked ark addresses
     */
    function arks() external view returns (address[] memory);

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
     * @notice Sets a new fee address
     * @param newAddress The new fee address
     */
    function setFeeAddress(address newAddress) external;

    /**
     * @notice Adds a new Ark
     * @param ark The address of the new Ark
     */
    function addArk(address ark) external;

    /**
     * @notice Adds multiple Arks in a batch
     * @param arks Array of ark addresses
     */
    function addArks(address[] calldata arks) external;

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
     * @param data Encoded force rebalance instructions
     */
    function forceRebalance(bytes calldata data) external;

    /**
     * @notice Initiates an emergency shutdown of the FleetCommander
     */
    function emergencyShutdown() external;

    /* FUNCTIONS - PUBLIC - FEES */
    /**
     * @notice Mints shares as fees
     */
    function mintSharesAsFees() external;
}
