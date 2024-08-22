// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./VotingDecayLibrary.sol";
import "./VotingDecayEvents.sol";
import "./VotingDecayErrors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingDecayManager
 * @notice Manages voting power decay for accounts in a governance system
 * @dev Implements decay calculations, delegation, and administrative functions
 */
contract VotingDecayManager is Ownable {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

    /// @notice Stores decay information for each account
    mapping(address => VotingDecayLibrary.DecayInfo) private decayInfoByAccount;
    /// @notice Maps delegates to their delegators
    mapping(address => address[]) public delegators;
    /// @notice Addresses authorized to refresh decay
    mapping(address => bool) public authorizedRefreshers;

    /// @notice Duration of the decay-free window in seconds
    uint40 public decayFreeWindow;
    /// @notice Rate of decay per second (in WAD format)
    uint256 public decayRatePerSecond;
    /// @notice Type of decay function used (Linear or Exponential)
    VotingDecayLibrary.DecayFunction public decayFunction;

    /**
     * @notice Constructor to initialize the VotingDecayManager
     * @param decayFreeWindow_ Initial decay-free window duration
     * @param decayRatePerSecond_ Initial decay rate per second
     * @param decayFunction_ Initial decay function type
     * @param owner Address of the contract owner
     */
    constructor(
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        VotingDecayLibrary.DecayFunction decayFunction_,
        address owner
    ) Ownable(owner) {
        decayFreeWindow = decayFreeWindow_;
        decayRatePerSecond = decayRatePerSecond_;
        decayFunction = decayFunction_;
        authorizedRefreshers[owner] = true;
    }

    /// @notice Modifier to ensure only authorized addresses can call a function
    modifier onlyAuthorized() {
        if (!authorizedRefreshers[msg.sender]) revert NotAuthorizedToReset();
        _;
    }

    /// @notice Modifier to update decay after function execution
    modifier decayUpdate(address toRefresh) {
        _;
        _updateRetentionFactor(toRefresh);
    }

    /// @notice Modifier to reset decay after function execution
    modifier decayReset(address toRefresh) {
        _;
        _resetDecay(toRefresh);
    }

    /**
     * @notice Sets a new decay rate per second
     * @param newRatePerSecond New decay rate (in WAD format)
     */
    function setDecayRatePerSecond(uint256 newRatePerSecond) external onlyOwner {
        if (!VotingDecayLibrary.isValidDecayRate(newRatePerSecond)) {
            revert InvalidDecayRate();
        }
        decayRatePerSecond = newRatePerSecond;
        emit VotingDecayEvents.DecayRateSet(newRatePerSecond);
    }

    /**
     * @notice Sets a new decay-free window duration
     * @param newWindow New decay-free window duration in seconds
     */
    function setDecayFreeWindow(uint40 newWindow) external onlyOwner {
        decayFreeWindow = newWindow;
        emit VotingDecayEvents.DecayFreeWindowSet(newWindow);
    }

    /**
     * @notice Sets a new decay function type
     * @param newFunction New decay function (Linear or Exponential)
     */
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external onlyOwner {
        decayFunction = newFunction;
        emit VotingDecayEvents.DecayFunctionSet(uint8(newFunction));
    }

    /**
     * @notice Authorizes or deauthorizes an address to refresh decay
     * @param refresher Address to authorize or deauthorize
     * @param isAuthorized True to authorize, false to deauthorize
     */
    function setAuthorizedRefresher(
        address refresher,
        bool isAuthorized
    ) external onlyOwner {
        authorizedRefreshers[refresher] = isAuthorized;
        emit VotingDecayEvents.AuthorizedRefresherSet(refresher, isAuthorized);
    }

    /**
     * @notice Resets the decay for a given account
     * @param accountAddress Address of the account to reset
     */
    function resetDecay(address accountAddress) public onlyAuthorized {
        _resetDecay(accountAddress);
    }

    /**
     * @notice Updates the decay for a given account
     * @param accountAddress Address of the account to update
     */
    function updateDecay(address accountAddress) public {
        _updateRetentionFactor(accountAddress);
    }

    /**
     * @notice Delegates voting power from one account to another
     * @param from Address delegating power
     * @param to Address receiving delegation
     */
    function delegate(address from, address to) external decayReset(from) {
        _initializeAccountIfNew(from);
        _initializeAccountIfNew(to);

        VotingDecayLibrary.DecayInfo storage fromAccount = decayInfoByAccount[from];
        if (fromAccount.delegateTo != address(0)) revert AlreadyDelegated();
        if (from == to) revert CannotDelegateToSelf();

        address currentDelegate = fromAccount.delegateTo;
        if (currentDelegate != address(0)) {
            _removeDelegator(currentDelegate, from);
        }

        delegators[to].push(from);
        fromAccount.delegateTo = to;

        emit VotingDecayEvents.Delegated(from, to);
    }

    /**
     * @notice Removes delegation for an account
     * @param accountAddress Address to remove delegation for
     */
    function undelegate(address accountAddress) external decayReset(accountAddress) {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage decayInfo = decayInfoByAccount[accountAddress];
        if (decayInfo.delegateTo == address(0)) revert NotDelegated();

        address currentDelegate = decayInfo.delegateTo;
        _removeDelegator(currentDelegate, accountAddress);

        decayInfo.delegateTo = address(0);
        _resetDecay(accountAddress);

        emit VotingDecayEvents.Undelegated(accountAddress);
    }

    /**
     * @notice Calculates the current voting power for an account
     * @param accountAddress Address to calculate voting power for
     * @param originalValue Original voting power value
     * @return Current voting power after applying decay
     */
    function getVotingPower(
        address accountAddress,
        uint256 originalValue
    ) external view returns (uint256) {
        if (decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            revert AccountNotInitialized();
        }

        uint256 retentionFactor = getCurrentRetentionFactor(accountAddress);

        return VotingDecayLibrary.applyDecay(originalValue, retentionFactor);
    }

    /**
     * @notice Gets the list of delegators for a given account
     * @param account Address to get delegators for
     * @return Array of delegator addresses
     */
    function getDelegators(address account) external view returns (address[] memory) {
        return delegators[account];
    }

    /**
     * @notice Calculates the current retention factor for an account
     * @param accountAddress Address to calculate retention factor for
     * @return Current retention factor
     */
    function getCurrentRetentionFactor(address accountAddress) public view returns (uint256) {
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[accountAddress];

        if (account.lastUpdateTimestamp == 0) {
            revert AccountNotInitialized();
        }

        if (account.delegateTo != address(0)) {
            return getCurrentRetentionFactor(account.delegateTo);
        }

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        return VotingDecayLibrary.calculateRetentionFactor(
            account.retentionFactor,
            decayPeriod,
            decayRatePerSecond,
            decayFreeWindow,
            decayFunction
        );
    }

    /**
     * @notice Gets the decay information for an account
     * @param accountAddress Address to get decay info for
     * @return DecayInfo struct containing decay information
     */
    function getDecayInfo(address accountAddress) public view returns (VotingDecayLibrary.DecayInfo memory) {
        return decayInfoByAccount[accountAddress];
    }

    /**
     * @notice Initializes an account if it hasn't been initialized yet
     * @param accountAddress Address of the account to initialize
     */
    function initializeAccount(address accountAddress) public {
        _initializeAccountIfNew(accountAddress);
    }

    /**
     * @notice Internal function to initialize an account if it's new
     * @param accountAddress Address of the account to initialize
     */
    function _initializeAccountIfNew(address accountAddress) internal {
        if (decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            decayInfoByAccount[accountAddress] = VotingDecayLibrary.DecayInfo({
                retentionFactor: VotingDecayLibrary.WAD,
                lastUpdateTimestamp: uint40(block.timestamp),
                delegateTo: address(0)
            });
        }
    }

    /**
     * @notice Internal function to update the retention factor for an account
     * @param accountAddress Address of the account to update
     */
    function _updateRetentionFactor(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[accountAddress];

        if (account.delegateTo != address(0)) {
            _updateRetentionFactor(account.delegateTo);
            return;
        }

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        if (decayPeriod > decayFreeWindow) {
            uint256 newRetentionFactor = getCurrentRetentionFactor(accountAddress);
            account.retentionFactor = newRetentionFactor;
        }
        account.lastUpdateTimestamp = uint40(block.timestamp);

        emit VotingDecayEvents.DecayUpdated(accountAddress, account.retentionFactor);
    }

    /**
     * @notice Internal function to reset the decay for an account
     * @param accountAddress Address of the account to reset
     */
    function _resetDecay(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[accountAddress];
        account.lastUpdateTimestamp = uint40(block.timestamp);
        account.retentionFactor = VotingDecayLibrary.WAD;
        emit VotingDecayEvents.DecayReset(accountAddress);
    }

    /**
     * @notice Internal function to remove a delegator from a delegate's list
     * @param delegate_ Address of the delegate
     * @param delegator Address of the delegator to remove
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
