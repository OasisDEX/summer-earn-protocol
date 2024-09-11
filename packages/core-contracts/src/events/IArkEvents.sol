// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title IArkEvents
 * @notice Interface for events emitted by Ark contracts
 */
interface IArkEvents {
    /**
     * @notice Emitted when rewards are harvested from an Ark
     * @param rewardTokens The addresses of the harvested reward tokens
     * @param rewardAmounts The amounts of the harvested reward tokens
     */
    event ArkHarvested(
        address[] indexed rewardTokens,
        uint256[] indexed rewardAmounts
    );

    /**
     * @notice Emitted when tokens are boarded (deposited) into the Ark
     * @param commander The address of the FleetCommander initiating the boarding
     * @param token The address of the token being boarded
     * @param amount The amount of tokens boarded
     */
    event Boarded(address indexed commander, address token, uint256 amount);

    /**
     * @notice Emitted when tokens are disembarked (withdrawn) from the Ark
     * @param commander The address of the FleetCommander initiating the disembarking
     * @param token The address of the token being disembarked
     * @param amount The amount of tokens disembarked
     */
    event Disembarked(address indexed commander, address token, uint256 amount);

    /**
     * @notice Emitted when tokens are moved from one address to another
     * @param from Ark being boarded from
     * @param to Ark being boarded to
     * @param token The address of the token being moved
     * @param amount The amount of tokens moved
     */
    event Moved(
        address indexed from,
        address indexed to,
        address token,
        uint256 amount
    );

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
     * @notice Emitted when the Ark is poked twice in the same block
     */
    event ArkPokedTooSoon();

    /**
     * @notice Emitted when the Ark is poked and the share price did not change
     */
    event ArkPokedNoChange();

    /**
     * @notice Emitted when the Ark is poked and the share price is updated
     * @param currentPrice Current share price of the Ark
     * @param timestamp The timestamp of the poke
     */
    event ArkPoked(uint256 currentPrice, uint256 timestamp);

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
