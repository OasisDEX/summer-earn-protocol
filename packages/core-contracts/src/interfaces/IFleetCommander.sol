// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IFleetCommanderAccessControl} from "./IFleetCommanderAccessControl.sol";
import {FleetCommanderParams, ArkConfiguration} from "../types/FleetCommanderTypes.sol";

/// @title IFleetCommander Interface
/// @notice Interface for the FleetCommander contract, which manages asset allocation across multiple Arks
interface IFleetCommander is IFleetCommanderAccessControl, IERC4626 {
    /* STRUCTS */
    /**
     * @notice Data structure for the rebalance event
     * @param fromArk The address of the Ark from which assets are moved
     * @param toArk The address of the Ark to which assets are moved
     * @param amount The amount of assets being moved
     */
    struct RebalanceEventData {
        address fromArk;
        address toArk;
        uint256 amount;
    }

    /* EVENTS */
    /**
     * @notice Emitted when a rebalance operation is completed
     * @param keeper The address of the keeper who initiated the rebalance
     * @param rebalances An array of RebalanceEventData structs detailing the rebalance operations
     */
    event Rebalanced(address indexed keeper, RebalanceEventData[] rebalances);

    /**
     * @notice Emitted when queued funds are committed
     * @param keeper The address of the keeper who committed the funds
     * @param prevBalance The previous balance before committing funds
     * @param newBalance The new balance after committing funds
     */
    event QueuedFundsCommitted(
        address indexed keeper,
        uint256 prevBalance,
        uint256 newBalance
    );

    /**
     * @notice Emitted when the funds queue is refilled
     * @param keeper The address of the keeper who initiated the queue refill
     * @param prevBalance The previous balance before refilling
     * @param newBalance The new balance after refilling
     */
    event FundsQueueRefilled(
        address indexed keeper,
        uint256 prevBalance,
        uint256 newBalance
    );

    /**
     * @notice Emitted when the minimum balance of the funds queue is updated
     * @param keeper The address of the keeper who updated the minimum balance
     * @param newBalance The new minimum balance
     */
    event MinFundsQueueBalanceUpdated(
        address indexed keeper,
        uint256 newBalance
    );

    /**
     * @notice Emitted when the deposit cap is updated
     * @param newCap The new deposit cap value
     */
    event DepositCapUpdated(uint256 newCap);

    /**
     * @notice Emitted when the fee address is updated
     * @param newAddress The new fee address
     */
    event FeeAddressUpdated(address newAddress);

    /**
     * @notice Emitted when a new Ark is added
     * @param ark The address of the newly added Ark
     * @param maxAllocation The maximum token allocation for the new Ark (token units)
     */
    event ArkAdded(address indexed ark, uint256 maxAllocation);

    /**
     * @notice Emitted when an Ark is removed
     * @param ark The address of the removed Ark
     */
    event ArkRemoved(address indexed ark);

    /**
     * @notice Emitted when an Ark's maximum allocation is updated
     * @param ark The address of the Ark
     * @param newMaxAllocation The new maximum allocation for the Ark (token units)
     */
    event ArkMaxAllocationUpdated(
        address indexed ark,
        uint256 newMaxAllocation
    );

    /**
     * @notice Emitted when the funds buffer balance is updated
     * @param user The address of the user who triggered the update
     * @param prevBalance The previous buffer balance
     * @param newBalance The new buffer balance
     */
    event FundsBufferBalanceUpdated(
        address indexed user,
        uint256 prevBalance,
        uint256 newBalance
    );

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

    /* FUNCTIONS - EXTERNAL - KEEPER */
    /**
     * @notice Rebalances the assets across Arks
     * @param data Encoded rebalance instructions
     */
    function rebalance(bytes calldata data) external;

    /**
     * @notice Adjusts the buffer of funds
     * @param data Encoded buffer adjustment instructions
     */
    function adjustBuffer(bytes calldata data) external;

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
