// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*
 * @title VotingDecayEvents
 * @notice Defines events related to voting decay operations
 * @dev This contract is meant to be inherited by contracts that need to emit these events
 */
contract VotingDecayEvents {
    /* @notice Emitted when an account's decay index is updated */
    event DecayUpdated(address indexed account, uint256 newDecayIndex);

    /* @notice Emitted when an account's decay rate is set */
    event DecayRateSet(address indexed account, uint256 newRate);

    /* @notice Emitted when an account's decay is reset */
    event DecayReset(address indexed account);

    /* @notice Emitted when an account's decay-free window is set */
    event DecayFreeWindowSet(address indexed account, uint256 window);

    /* @notice Emitted when an account delegates its voting power */
    event Delegated(address indexed from, address indexed to);

    /* @notice Emitted when an account undelegates its voting power */
    event Undelegated(address indexed account);

    event AuthorizedRefresherSet(address indexed refresher, bool isAuthorized);
}
