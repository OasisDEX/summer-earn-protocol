// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./VotingDecayLibrary.sol";
import "./VotingDecayEvents.sol";

/*
 * @title VotingDecayManager
 * @notice Manages the decay of voting power for accounts in a governance system
 * @dev This contract handles the initialization, updating, and querying of voting power decay
 */
contract VotingDecayManager {
    using VotingDecayLibrary for VotingDecayLibrary.Account;

    /* @notice Mapping of addresses to their voting decay accounts */
    mapping(address => VotingDecayLibrary.Account) public accounts;

    /*
     * @notice Initializes an account if it doesn't exist
     * @param accountAddress The address of the account to initialize
     */
    function initializeAccountIfNew(address accountAddress) internal {
        if (accounts[accountAddress].lastUpdateTimestamp == 0) {
            accounts[accountAddress] = VotingDecayLibrary.Account({
                decayIndex: VotingDecayLibrary.RAY,
                lastUpdateTimestamp: block.timestamp,
                decayRate: 0,
                delegateTo: address(0),
                decayFreeWindow: 0
            });
        }
    }

    /*
     * @notice Get the current decay index for an account
     * @param accountAddress The address of the account to query
     * @return The current decay index
     */
    function getCurrentDecayIndex(address accountAddress) public view returns (uint256) {
        VotingDecayLibrary.Account storage account = accounts[accountAddress];
        if (account.lastUpdateTimestamp == 0) {
            return VotingDecayLibrary.RAY; // Return initial decay index for uninitialized accounts
        }
        if (account.delegateTo != address(0)) {
            return getCurrentDecayIndex(account.delegateTo);
        }

        uint256 elapsed = block.timestamp - account.lastUpdateTimestamp;
        return VotingDecayLibrary.calculateDecayIndex(
            account.decayIndex,
            elapsed,
            account.decayRate,
            account.decayFreeWindow
        );
    }

    /*
     * @notice Update the decay index for an account
     * @param accountAddress The address of the account to update
     */
    function updateDecayIndex(address accountAddress) internal {
        initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.Account storage account = accounts[accountAddress];
        if (account.delegateTo != address(0)) {
            updateDecayIndex(account.delegateTo);
            return;
        }

        uint256 newDecayIndex = getCurrentDecayIndex(accountAddress);
        account.decayIndex = newDecayIndex;
        account.lastUpdateTimestamp = block.timestamp;

        emit VotingDecayEvents.DecayUpdated(accountAddress, newDecayIndex);
    }

    /*
     * @notice Reset the decay for an account
     * @param accountAddress The address of the account to reset
     */
    function resetDecay(address accountAddress) internal {
        initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.Account storage account = accounts[accountAddress];
        account.lastUpdateTimestamp = block.timestamp;
        account.decayIndex = VotingDecayLibrary.RAY;
        emit VotingDecayEvents.DecayReset(accountAddress);
    }

    /*
     * @notice Set the decay rate for an account
     * @param accountAddress The address of the account
     * @param rate The new decay rate
     */
    function setDecayRate(address accountAddress, uint256 rate) external {
        require(VotingDecayLibrary.isValidDecayRate(rate), "Invalid decay rate");
        initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.Account storage account = accounts[accountAddress];
        account.decayRate = rate;
        emit VotingDecayEvents.DecayRateSet(accountAddress, rate);
    }

    /*
     * @notice Set the decay-free window for an account
     * @param accountAddress The address of the account
     * @param window The new decay-free window duration
     */
    function setDecayFreeWindow(address accountAddress, uint256 window) external {
        initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.Account storage account = accounts[accountAddress];
        account.decayFreeWindow = window;
        emit VotingDecayEvents.DecayFreeWindowSet(accountAddress, window);
    }

    /*
     * @notice Refresh the decay for an account
     * @param accountAddress The address of the account to refresh
     */
    function refreshDecay(address accountAddress) external {
        updateDecayIndex(accountAddress);
        resetDecay(accountAddress);
    }

    /*
     * @notice Delegate voting power from one account to another
     * @param from The address delegating power
     * @param to The address receiving the delegation
     */
    function delegate(address from, address to) external {
        initializeAccountIfNew(from);
        initializeAccountIfNew(to);

        VotingDecayLibrary.Account storage fromAccount = accounts[from];
        require(fromAccount.delegateTo == address(0), "Already delegated");
        require(from != to, "Cannot delegate to self");

        updateDecayIndex(from);

        fromAccount.delegateTo = to;

        emit VotingDecayEvents.Delegated(from, to);
    }

    /*
     * @notice Remove delegation for an account
     * @param accountAddress The address to undelegate
     */
    function undelegate(address accountAddress) external {
        initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.Account storage account = accounts[accountAddress];
        require(account.delegateTo != address(0), "Not delegated");

        account.delegateTo = address(0);
        resetDecay(accountAddress);

        emit VotingDecayEvents.Undelegated(accountAddress);
    }

    /*
     * @notice Get the current voting power for an account
     * @param accountAddress The address of the account
     * @param originalVotingPower The original voting power before decay
     * @return The current voting power after applying decay
     */
    function getVotingPower(address accountAddress, uint256 originalVotingPower) external view returns (uint256) {
        uint256 decayIndex = getCurrentDecayIndex(accountAddress);
        return VotingDecayLibrary.applyDecayToVotingPower(originalVotingPower, decayIndex);
    }

    /*
     * @notice Get the decay rate for an account
     * @param accountAddress The address of the account
     * @return The decay rate of the account
     */
    function getDecayRate(address accountAddress) public view returns (uint256) {
        return accounts[accountAddress].decayRate;
    }
}
