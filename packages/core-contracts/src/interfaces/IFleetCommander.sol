// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {FleetCommanderParams, RebalanceData} from "../types/FleetCommanderTypes.sol";
import {IFleetCommanderEvents} from "../events/IFleetCommanderEvents.sol";
import "../types/Percentage.sol";

/**
 * @title IFleetCommander Interface
 * @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
 */
interface IFleetCommander is IFleetCommanderEvents, IERC4626 {
    /**
     * @notice Retrieves the arks currently linked to fleet
     * @return An array of linked ark addresses
     */
    function arks(uint256 index) external view returns (address);

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
     * @dev This function requires a parameter that specifies the new tip jar address.
     */
    function setTipJar() external;

    /**
     * @notice Sets a new tip rate
     * @param newTipRateNumerator The new tip rate for the fleet
     * @param newTipRateDenominator The new tip rate denominator (for fine tune setting)
     */
    function setTipRate(
        uint256 newTipRateNumerator,
        uint256 newTipRateDenominator
    ) external;

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
