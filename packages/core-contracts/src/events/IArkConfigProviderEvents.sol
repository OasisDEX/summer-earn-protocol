// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IArkConfigProviderEvents
 * @notice Interface for events emitted by ArkConfigProvider contracts
 */
interface IArkConfigProviderEvents {
    /**
     * @notice Emitted when the deposit cap of the Ark is updated
     * @param newCap The new deposit cap value
     */
    event DepositCapUpdated(uint256 newCap);

    /**
     * @notice Emitted when the Raft address associated with the Ark is updated
     * @param newRaft The address of the new Raft
     */
    event RaftUpdated(address newRaft);

    /**
     * @notice Emitted when the maximum outflow limit for the Ark during rebalancing is updated
     * @param newMaxOutflow The new maximum amount that can be transferred out of the Ark during a rebalance
     */
    event MaxRebalanceOutflowUpdated(uint256 newMaxOutflow);

    /**
     * @notice Emitted when the maximum inflow limit for the Ark during rebalancing is updated
     * @param newMaxInflow The new maximum amount that can be transferred into the Ark during a rebalance
     */
    event MaxRebalanceInflowUpdated(uint256 newMaxInflow);
}
