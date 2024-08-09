// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./VotingDecayLibrary.sol";
import "./VotingDecayEvents.sol";
import "./VotingDecayErrors.sol";

/*
 * @title VotingDecayManager
 * @notice Manages the decay of voting power for accounts in a governance system
 * @dev This contract handles the initialization, updating, and querying of voting power decay
 */
contract VotingDecayManager {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

    /* @notice Mapping of addresses to their voting decay accounts */
    mapping(address => VotingDecayLibrary.DecayInfo) private decayInfoByAccount;
    /* @notice Mapping of addresses to their delegators */
    mapping(address => address[]) public delegators;

    // External functions

    /*
     * @notice Set the decay rate for an account
     * @param accountAddress The address of the account
     * @param rate The new decay rate
     */
    function setDecayRate(address accountAddress, uint256 rate) external {
        if (!VotingDecayLibrary.isValidDecayRate(rate)) revert InvalidDecayRate();
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[accountAddress];
        account.decayRate = rate;
        emit VotingDecayEvents.DecayRateSet(accountAddress, rate);
    }

    /*
     * @notice Set the decay-free window for an account
     * @param accountAddress The address of the account
     * @param window The new decay-free window duration
     */
    function setDecayFreeWindow(
        address accountAddress,
        uint256 window
    ) external {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        account.decayFreeWindow = window;
        emit VotingDecayEvents.DecayFreeWindowSet(accountAddress, window);
    }

    /*
     * @notice Refresh the decay for an account
     * @param accountAddress The address of the account to refresh
     */
    function refreshDecay(address accountAddress) external {
        _updateDecayIndex(accountAddress);
        _resetDecay(accountAddress);
    }

    /*
     * @notice Delegate voting power from one account to another
     * @param from The address delegating power
     * @param to The address receiving the delegation
     */
    function delegate(address from, address to) external {
        _initializeAccountIfNew(from);
        _initializeAccountIfNew(to);

        VotingDecayLibrary.DecayInfo storage fromAccount = decayInfoByAccount[from];
        if (fromAccount.delegateTo != address(0)) revert AlreadyDelegated();
        if (from == to) revert CannotDelegateToSelf();

        _updateDecayIndex(from);

        // Remove 'from' from previous delegate's delegators list (if any)
        address currentDelegate = fromAccount.delegateTo;
        if (currentDelegate != address(0)) {
            _removeDelegator(currentDelegate, from);
        }

        // Add 'from' to new delegate's delegators list
        delegators[to].push(from);

        // Update delegation info
        fromAccount.delegateTo = to;

        emit VotingDecayEvents.Delegated(from, to);
    }

    /*
     * @notice Remove delegation for an account
     * @param accountAddress The address to undelegate
     */
    function undelegate(address accountAddress) external {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage decayInfo = decayInfoByAccount[accountAddress];
        if (decayInfo.delegateTo == address(0)) revert NotDelegated();

        address currentDelegate = decayInfo.delegateTo;
        _removeDelegator(currentDelegate, accountAddress);

        decayInfo.delegateTo = address(0);
        _resetDecay(accountAddress);

        emit VotingDecayEvents.Undelegated(accountAddress);
    }

    /*
     * @notice Get the current voting power for an account
     * @param accountAddress The address of the account
     * @param originalVotingPower The original voting power before decay
     * @return The current voting power after applying decay
     */
    function getVotingPower(
        address accountAddress,
        uint256 originalVotingPower
    ) external view returns (uint256) {
        uint256 decayIndex = getCurrentDecayIndex(accountAddress);
        return
            VotingDecayLibrary.applyDecayToVotingPower(
                originalVotingPower,
                decayIndex
            );
    }

    /*
     * @notice Get the list of delegators for an account
     * @param account The address of the account
     * @return An array of addresses representing the delegators
     */
    function getDelegators(
        address account
    ) external view returns (address[] memory) {
        return delegators[account];
    }

    // Public functions

    /*
     * @notice Get the current decay index for an account
     * @param accountAddress The address of the account to query
     * @return The current decay index
     */
    function getCurrentDecayIndex(
        address accountAddress
    ) public view returns (uint256) {
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        if (account.lastUpdateTimestamp == 0) {
            return VotingDecayLibrary.RAY; // Return initial decay index for uninitialized accounts
        }
        if (account.delegateTo != address(0)) {
            return getCurrentDecayIndex(account.delegateTo);
        }

        uint256 elapsed = block.timestamp - account.lastUpdateTimestamp;
        return
            VotingDecayLibrary.calculateDecayIndex(
                account.decayIndex,
                elapsed,
                account.decayRate,
                account.decayFreeWindow
            );
    }

    /*
     * @notice Get the decay rate for an account
     * @param accountAddress The address of the account
     * @return The decay rate of the account
     */
    function getDecayRate(
        address accountAddress
    ) public view returns (uint256) {
        return decayInfoByAccount[accountAddress].decayRate;
    }

    /*
     * @notice Get the decay info for an account
     * @param accountAddress The address of the account
     * @return The DecayInfo struct for the account
     */
    function getDecayInfo(
        address accountAddress
    ) public view returns (VotingDecayLibrary.DecayInfo memory) {
        return decayInfoByAccount[accountAddress];
    }

    // Internal functions

    /*
     * @notice Initializes an account if it doesn't exist
     * @param accountAddress The address of the account to initialize
     */
    function _initializeAccountIfNew(address accountAddress) internal {
        if (decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            decayInfoByAccount[accountAddress] = VotingDecayLibrary.DecayInfo({
                decayIndex: VotingDecayLibrary.RAY,
                lastUpdateTimestamp: block.timestamp,
                decayRate: 0,
                delegateTo: address(0),
                decayFreeWindow: 0
            });
        }
    }

    /*
     * @notice Update the decay index for an account
     * @param accountAddress The address of the account to update
     */
    function _updateDecayIndex(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        if (account.delegateTo != address(0)) {
            _updateDecayIndex(account.delegateTo);
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
    function _resetDecay(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        account.lastUpdateTimestamp = block.timestamp;
        account.decayIndex = VotingDecayLibrary.RAY;
        emit VotingDecayEvents.DecayReset(accountAddress);
    }

    /*
     * @notice Remove a delegator from a delegate's list
     * @param delegate_ The address of the delegate
     * @param delegator The address of the delegator to remove
     */
    function _removeDelegator(address delegate_, address delegator) internal {
        address[] storage delegatorList = delegators[delegate_];
        for (uint i = 0; i < delegatorList.length; i++) {
            if (delegatorList[i] == delegator) {
                delegatorList[i] = delegatorList[delegatorList.length - 1];
                delegatorList.pop();
                break;
            }
        }
    }
}
