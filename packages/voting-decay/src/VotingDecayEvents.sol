// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract VotingDecayEvents {
    event DecayUpdated(address indexed account, uint256 newRetentionFactor);
    event DecayRateSet(uint256 newRate);
    event DecayReset(address indexed account);
    event DecayFreeWindowSet(uint256 window);
    event Delegated(address indexed from, address indexed to);
    event Undelegated(address indexed account);
    event AuthorizedRefresherSet(address indexed refresher, bool isAuthorized);
    event DecayFunctionSet(uint8 newFunction);
}
