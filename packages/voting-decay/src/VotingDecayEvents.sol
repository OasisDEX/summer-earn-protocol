// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title VotingDecayEvents
 * @notice This contract defines events related to voting decay mechanisms
 * @dev These events are emitted by the VotingDecayManager contract
 */
contract VotingDecayEvents {
    /**
     * @notice Emitted when an account's decay factor is updated
     * @param account The address of the account whose decay factor was updated
     * @param newRetentionFactor The new retention factor after the update
     */
    event DecayUpdated(address indexed account, uint256 newRetentionFactor);

    /**
     * @notice Emitted when the global decay rate is changed
     * @param newRate The new decay rate
     */
    event DecayRateSet(uint256 newRate);

    /**
     * @notice Emitted when an account's decay is reset to its initial state
     * @param account The address of the account whose decay was reset
     */
    event DecayReset(address indexed account);

    /**
     * @notice Emitted when the decay-free window duration is changed
     * @param window The new duration of the decay-free window
     */
    event DecayFreeWindowSet(uint256 window);

    /**
     * @notice Emitted when an account delegates its voting power to another account
     * @param from The address of the account delegating its power
     * @param to The address of the account receiving the delegation
     */
    event Delegated(address indexed from, address indexed to);

    /**
     * @notice Emitted when an account removes its delegation
     * @param account The address of the account that undelegated
     */
    event Undelegated(address indexed account);

    /**
     * @notice Emitted when an address is authorized or deauthorized to refresh decay
     * @param refresher The address being authorized or deauthorized
     * @param isAuthorized True if the address is being authorized, false if deauthorized
     */
    event AuthorizedRefresherSet(address indexed refresher, bool isAuthorized);

    /**
     * @notice Emitted when the decay function type is changed
     * @param newFunction The new decay function type (0 for Linear, 1 for Exponential)
     */
    event DecayFunctionSet(uint8 newFunction);
}
