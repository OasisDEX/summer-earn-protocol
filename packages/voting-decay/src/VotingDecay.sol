// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IVotingDecay.sol";
import "./VotingDecayMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title VotingDecay
 * @dev A library for managing voting power decay in governance systems.
 * This library provides functions to calculate, update, and manage voting power
 * that decays over time, as well as delegation mechanisms.
 */
library VotingDecay {
    using VotingDecayMath for uint256;

    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /**
     * @dev Calculates the amount of voting power decay over a given time period.
     * @param notionalAmount The initial voting power amount.
     * @param elapsedTime The time period over which to calculate decay.
     * @return The amount of voting power that has decayed.
     */
    function calculateDecay(uint256 notionalAmount, uint256 elapsedTime) internal pure returns (uint256) {
        return notionalAmount.mulDiv(elapsedTime, SECONDS_PER_YEAR);
    }

    /**
     * @dev Retrieves the current voting power of an account, taking into account decay.
     * @param account The account to check.
     * @return The current voting power of the account.
     */
    function getCurrentVotingPower(IVotingDecay.Account storage account) internal view returns (uint256) {
        if (account.delegateTo != address(0)) {
            return 0; // If delegated, the account itself has no voting power
        }

        uint256 elapsed = block.timestamp - account.lastUpdateTimestamp;
        uint256 decay = calculateDecay(account.votingPower, elapsed);
        return Math.max(account.votingPower - decay, 0);
    }

    /**
     * @dev Updates the voting power of an account by applying decay.
     * @param account The account to update.
     */
    function updateDecay(IVotingDecay.Account storage account) internal {
        if (account.delegateTo != address(0)) {
            return; // If delegated, no need to update decay
        }

        uint256 newVotingPower = getCurrentVotingPower(account);
        account.votingPower = newVotingPower;
        account.lastUpdateTimestamp = block.timestamp;

        emit IVotingDecay.DecayUpdated(address(this), newVotingPower);
    }

    /**
     * @dev Resets the decay timer for an account.
     * @param account The account to reset.
     */
    function resetDecay(IVotingDecay.Account storage account) internal {
        account.lastUpdateTimestamp = block.timestamp;
        emit IVotingDecay.DecayReset(address(this));
    }

    /**
     * @dev Applies decay to an account's voting power.
     * @param account The account to apply decay to.
     */
    function applyDecay(IVotingDecay.Account storage account) internal {
        updateDecay(account);
    }

    /**
     * @dev Sets the decay rate for an account.
     * @param account The account to set the decay rate for.
     * @param rate The new decay rate (must be <= 1e18, representing 100%).
     */
    function setDecayRate(IVotingDecay.Account storage account, uint256 rate) internal {
        // TODO: Use Percentage.sol
        require(rate <= 1e18, "Decay rate must be <= 100%");
        account.decayRate = rate;
        emit IVotingDecay.DecayRateSet(address(this), rate);
    }

    /**
     * @dev Refreshes an account's decay by updating and resetting it.
     * @param account The account to refresh.
     */
    function refreshDecay(IVotingDecay.Account storage account) internal {
        updateDecay(account);
        resetDecay(account);
    }

    /**
     * @dev Delegates voting power from one account to another.
     * @param from The account delegating power.
     * @param to The account receiving the delegation.
     */
    function delegate(IVotingDecay.Account storage from, IVotingDecay.Account storage to) internal {
        require(from.delegateTo == address(0), "Already delegated");
        require(from.delegateTo != to.delegateTo, "Cannot delegate to self");

        updateDecay(from);
        updateDecay(to);

        to.votingPower += from.votingPower;
        from.votingPower = 0;
        from.delegateTo = to.delegateTo;

        emit IVotingDecay.Delegated(from.delegateTo, to.delegateTo);
    }

    /**
     * @dev Removes delegation from an account, returning voting power.
     * @param account The account to undelegate.
     * @param accounts A mapping of all accounts, used to access the delegate's account.
     */
    function undelegate(IVotingDecay.Account storage account, mapping(address => IVotingDecay.Account) storage accounts) internal {
        require(account.delegateTo != address(0), "Not delegated");

        address delegateAddress = account.delegateTo;
        IVotingDecay.Account storage delegateAccount = accounts[delegateAddress];

        updateDecay(delegateAccount);

        uint256 returnedVotingPower = getCurrentVotingPower(delegateAccount);
        delegateAccount.votingPower -= returnedVotingPower;
        account.votingPower = returnedVotingPower;
        account.delegateTo = address(0);
        account.lastUpdateTimestamp = block.timestamp;

        emit IVotingDecay.Undelegated(address(this));
    }

//    /**
//     * @dev Retrieves an account from a mapping.
//     * @param account The address of the account to retrieve.
//     * @return The Account struct for the given address.
//     * @notice This function should be implemented in the contract that uses this library.
//     */
//    function getAccount(address account) internal view returns (IVotingDecay.Account storage) {
//        // This function should be implemented in the contract that uses this library
//        revert("Not implemented");
//    }
}
