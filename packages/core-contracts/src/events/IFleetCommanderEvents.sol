// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {RebalanceData} from "../types/FleetCommanderTypes.sol";

interface IFleetCommanderEvents {
    /* EVENTS */
    /**
     * @notice Emitted when a rebalance operation is completed
     * @param keeper The address of the keeper who initiated the rebalance
     * @param rebalances An array of RebalanceData structs detailing the rebalance operations
     */
    event Rebalanced(address indexed keeper, RebalanceData[] rebalances);

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
     *
     * @param keeper Keeper address
     * @param totalMoved Total amount of funds moved to arks
     */
    event FleetCommanderBufferAdjusted(
        address indexed keeper,
        uint256 totalMoved
    );
    /**
     *
     * @param newCooldown New rebalance cooldown period
     */
    event RebalanceCooldownUpdated(uint256 newCooldown);
}
