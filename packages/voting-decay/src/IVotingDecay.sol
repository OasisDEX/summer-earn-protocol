// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IVotingDecay {
    struct Account {
        uint256 votingPower;
        uint256 lastUpdateTimestamp;
        uint256 decayRate;
        address delegate;
    }

    function calculateDecay(uint256 notionalAmount, uint256 elapsedTime) external view returns (uint256);

    function getCurrentVotingPower(address account) external view returns (uint256);

    function updateDecay(address account) external;

    function resetDecay(address account) external;

    function applyDecay(address account) external;

    function setDecayRate(address account, uint256 rate) external;

    function refreshDecay(address account) external;

    function delegate(address from, address to) external;

    function undelegate(address account) external;

    // Events
    event DecayUpdated(address indexed account, uint256 newVotingPower);
    event DecayRateSet(address indexed account, uint256 newRate);
    event DecayReset(address indexed account);
    event Delegated(address indexed from, address indexed to);
    event Undelegated(address indexed account);
}
