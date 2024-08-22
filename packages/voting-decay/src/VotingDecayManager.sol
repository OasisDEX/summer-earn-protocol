// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./VotingDecayLibrary.sol";
import "./VotingDecayEvents.sol";
import "./VotingDecayErrors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VotingDecayManager is Ownable {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

    mapping(address => VotingDecayLibrary.DecayInfo) private decayInfoByAccount;
    mapping(address => address[]) public delegators;
    mapping(address => bool) public authorizedRefreshers;

    uint40 public decayFreeWindow;
    uint256 public decayRatePerSecond;
    VotingDecayLibrary.DecayFunction public decayFunction;

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

    modifier onlyAuthorized() {
        if (!authorizedRefreshers[msg.sender]) revert NotAuthorizedToReset();
        _;
    }

    modifier decayUpdate(address toRefresh) {
        _;
        _updateRetentionFactor(toRefresh);
    }

    modifier decayReset(address toRefresh) {
        _;
        _resetDecay(toRefresh);
    }

    function setDecayRatePerSecond(uint256 newRatePerSecond) external onlyOwner {
        if (!VotingDecayLibrary.isValidDecayRate(newRatePerSecond)) {
            revert InvalidDecayRate();
        }
        decayRatePerSecond = newRatePerSecond;
        emit VotingDecayEvents.DecayRateSet(newRatePerSecond);
    }

    function setDecayFreeWindow(uint40 newWindow) external onlyOwner {
        decayFreeWindow = newWindow;
        emit VotingDecayEvents.DecayFreeWindowSet(newWindow);
    }

    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external onlyOwner {
        decayFunction = newFunction;
        emit VotingDecayEvents.DecayFunctionSet(uint8(newFunction));
    }

    function setAuthorizedRefresher(
        address refresher,
        bool isAuthorized
    ) external onlyOwner {
        authorizedRefreshers[refresher] = isAuthorized;
        emit VotingDecayEvents.AuthorizedRefresherSet(refresher, isAuthorized);
    }

    function resetDecay(address accountAddress) public onlyAuthorized {
        _resetDecay(accountAddress);
    }

    function updateDecay(address accountAddress) public {
        _updateRetentionFactor(accountAddress);
    }

    function delegate(address from, address to) external decayReset(from) {
        _initializeAccountIfNew(from);
        _initializeAccountIfNew(to);

        VotingDecayLibrary.DecayInfo storage fromAccount = decayInfoByAccount[
            from
        ];
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

    function undelegate(
        address accountAddress
    ) external decayReset(accountAddress) {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage decayInfo = decayInfoByAccount[
            accountAddress
        ];
        if (decayInfo.delegateTo == address(0)) revert NotDelegated();

        address currentDelegate = decayInfo.delegateTo;
        _removeDelegator(currentDelegate, accountAddress);

        decayInfo.delegateTo = address(0);
        _resetDecay(accountAddress);

        emit VotingDecayEvents.Undelegated(accountAddress);
    }

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

    function getDelegators(
        address account
    ) external view returns (address[] memory) {
        return delegators[account];
    }

    function getCurrentRetentionFactor(
        address accountAddress
    ) public view returns (uint256) {
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];

        if (account.lastUpdateTimestamp == 0) {
            revert AccountNotInitialized();
        }

        if (account.delegateTo != address(0)) {
            return getCurrentRetentionFactor(account.delegateTo);
        }

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        return
            VotingDecayLibrary.calculateRetentionFactor(
                account.retentionFactor,
                decayPeriod,
                decayRatePerSecond,
                decayFreeWindow,
                decayFunction
            );
    }

    function getDecayInfo(
        address accountAddress
    ) public view returns (VotingDecayLibrary.DecayInfo memory) {
        return decayInfoByAccount[accountAddress];
    }

    function initializeAccount(address accountAddress) public {
        _initializeAccountIfNew(accountAddress);
    }

    function _initializeAccountIfNew(address accountAddress) internal {
        if (decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            decayInfoByAccount[accountAddress] = VotingDecayLibrary.DecayInfo({
                retentionFactor: VotingDecayLibrary.WAD,
                lastUpdateTimestamp: uint40(block.timestamp),
                delegateTo: address(0)
            });
        }
    }

    function _updateRetentionFactor(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        if (account.delegateTo != address(0)) {
            _updateRetentionFactor(account.delegateTo);
            return;
        }

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        if (decayPeriod > decayFreeWindow) {
            uint256 newRetentionFactor = getCurrentRetentionFactor(
                accountAddress
            );
            account.retentionFactor = newRetentionFactor;
        }
        account.lastUpdateTimestamp = uint40(block.timestamp);

        emit VotingDecayEvents.DecayUpdated(
            accountAddress,
            account.retentionFactor
        );
    }

    function _resetDecay(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        account.lastUpdateTimestamp = uint40(block.timestamp);
        account.retentionFactor = VotingDecayLibrary.WAD;
        emit VotingDecayEvents.DecayReset(accountAddress);
    }

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
