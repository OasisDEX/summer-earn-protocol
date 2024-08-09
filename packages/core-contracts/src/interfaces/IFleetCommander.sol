// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderParams, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IFleetCommanderEvents} from "../events/IFleetCommanderEvents.sol";
import {Percentage} from "../types/Percentage.sol";

/**
 * @title IFleetCommander Interface
 * @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
 */
interface IFleetCommander is IFleetCommanderEvents, IERC4626 {
    /**
     * @notice Retrieves the ark address at the specified index
     * @param index The index of the ark in the arks array
     * @return The address of the ark at the specified index
     */
    function arks(uint256 index) external view returns (address);

    /**
     * @notice Retrieves the arks currently linked to fleet
     */
    function getArks() external view returns (address[] memory);

    /**
     * @notice Checks if the ark is part of the fleet
     * @param ark The address of the Ark
     * @return bool Returns true if the ark is active, false otherwise.
     */
    function isArkActive(address ark) external view returns (bool);

    /**
     * @notice Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, directly from Buffer.
     * @param owner The address of the owner of the assets
     * @return uint256 The maximum amount that can be withdrawn.
     */
    function maxBufferWithdraw(address owner) external view returns (uint256);

    /* FUNCTIONS - PUBLIC - USER */
    /**
     * @notice Forces a withdrawal of assets from the FleetCommander
     * @param assets The amount of assets to forcefully withdraw
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the assets
     * @return shares The amount of shares redeemed
     */
    function withdrawFromArks(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Redeems shares for assets from the FleetCommander
     * @param shares The amount of shares to redeem
     * @param receiver  The address that will receive the assets
     * @param owner The address of the owner of the shares
     * @return assets The amount of assets forcefully withdrawn
     */
    function redeemFromArks(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @notice Redeems shares for assets directly from the Buffer
     * @param shares The amount of shares to redeem
     * @param receiver The address that will receive the assets
     * @param owner The address of the owner of the shares
     * @return assets The amount of assets redeemed
     */
    function redeemFromBuffer(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /**
     * @notice Forces a withdrawal of assets directly from the Buffer
     * @param assets The amount of assets to withdraw
     * @param receiver The address that will receive the withdrawn assets
     * @param owner The address of the owner of the assets
     * @return shares The amount of shares redeemed
     */
    function withdrawFromBuffer(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Accrues and distributes tips
     * @return uint256 The amount of tips accrued
     */
    function tip() external returns (uint256);

    /* FUNCTIONS - EXTERNAL - KEEPER */
    /**
     * @notice Rebalances the assets across Arks
     * @param data Array of RebalanceData structs
     * @dev RebalanceData struct contains:
     *      - fromArk: The address of the Ark to move assets from
     *      - toArk: The address of the Ark to move assets to
     *      - amount: The amount of assets to move
     * @dev Using type(uint256).max as the amount will move all assets from the fromArk to the toArk
     * @dev Rebalance operations cannot involve the buffer Ark directly
     * @dev The number of operations in a single rebalance call is limited to MAX_REBALANCE_OPERATIONS
     * @dev Rebalance is subject to a cooldown period between calls
     * @dev Only callable by accounts with the Keeper role
     */
    function rebalance(RebalanceData[] calldata data) external;

    /**
     * @notice Adjusts the buffer of funds by moving assets between the buffer Ark and other Arks
     * @param data Array of RebalanceData structs
     * @dev RebalanceData struct contains:
     *      - fromArk: The address of the Ark to move assets from (must be buffer Ark for withdrawing from buffer)
     *      - toArk: The address of the Ark to move assets to (must be buffer Ark for depositing to buffer)
     *      - amount: The amount of assets to move
     * @dev Unlike rebalance, adjustBuffer operations must involve the buffer Ark
     * @dev All operations in a single adjustBuffer call must be in the same direction (either all to buffer or all from buffer)
     * @dev type(uint256).max is not allowed as an amount for buffer adjustments
     * @dev When withdrawing from the buffer, the total amount moved cannot reduce the buffer balance below minFundsBufferBalance
     * @dev The number of operations in a single adjustBuffer call is limited to MAX_REBALANCE_OPERATIONS
     * @dev AdjustBuffer is subject to a cooldown period between calls
     * @dev Only callable by accounts with the Keeper role
     */
    function adjustBuffer(RebalanceData[] calldata data) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */

    /**
     * @notice Sets a new tip jar address
     * @dev This function sets the tipJar address to the address specified in the configuration manager.
     */
    function setTipJar() external;

    /**
     * @notice Sets a new tip rate
     * @param newTipRate The new tip rate as a Percentage
     * @dev The tip rate is set as a Percentage. Percentages use 18 decimals of precision
     *      For example, for a 5% rate, you'd pass 5 * 1e18 (5 000 000 000 000 000 000)
     */
    function setTipRate(Percentage newTipRate) external;

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
     * @notice Sets a new deposit cap for Fleet
     * @param newDepositCap The new deposit cap
     */
    function setFleetDepositCap(uint256 newDepositCap) external;

    /**
     * @notice Sets a new deposit cap for an Ark
     * @param ark The address of the Ark
     * @param newDepositCap The new deposit cap
     */
    function setArkDepositCap(address ark, uint256 newDepositCap) external;

    /**
     * @notice Sets the moveFromMax for an Ark
     * @dev Only callable by the governor
     * @param ark The address of the Ark
     * @param newMoveFromMax The new moveFromMax value
     */
    function setArkMoveFromMax(address ark, uint256 newMoveFromMax) external;

    /**
     * @notice Sets the moveToMax for an Ark
     * @dev Only callable by the governor
     * @param ark The address of the Ark
     * @param newMoveToMax The new moveToMax value
     */
    function setArkMoveToMax(address ark, uint256 newMoveToMax) external;

    /**
     * @dev Sets the minimum rate difference for the Fleet Commander.
     * @param newRateDifference The new minimum rate difference to be set.
     */
    function setMinimumRateDifference(Percentage newRateDifference) external;
    /**
     * @notice Updates the rebalance cooldown period
     * @param newCooldown The new cooldown period in seconds
     */
    function updateRebalanceCooldown(uint256 newCooldown) external;

    /**
     * @notice Forces a rebalance operation
     * @param data Array of typed rebalance data struct
     * @dev has no cooldown enforced but only callable by privileged role
     */
    function forceRebalance(RebalanceData[] calldata data) external;

    /**
     * @notice Initiates an emergency shutdown of the FleetCommander
     * @dev This action can only be performed under critical circumstances and typically by governance or a privileged role.
     */
    function emergencyShutdown() external;
}
