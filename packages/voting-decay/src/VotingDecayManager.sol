// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VotingDecayLibrary} from "./VotingDecayLibrary.sol";
import {IVotingDecayManager} from "./IVotingDecayManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, console} from "forge-std/Test.sol";

// TODO: Refactor decayReset from delegate and undelegate
// TODO: We don't need to track delegators, can just use the delegatee
// OQ: How do we track the decay of the delegators if we're not tracking delegateTo?

/**
 * @title VotingDecayManager
 * @notice Manages voting power decay for accounts in a governance system
 * @dev Implements decay calculations, delegation, and administrative functions
 */
abstract contract VotingDecayManager is IVotingDecayManager, Ownable {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

    /// @notice Stores decay information for each account
    mapping(address account => VotingDecayLibrary.DecayInfo info)
        private decayInfoByAccount;

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
     */
    constructor(
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        VotingDecayLibrary.DecayFunction decayFunction_
    ) Ownable(msg.sender) {
        decayFreeWindow = decayFreeWindow_;
        decayRatePerSecond = decayRatePerSecond_;
        decayFunction = decayFunction_;
    }

    /**
     * @notice Sets a new decay rate per second
     * @param newRatePerSecond New decay rate (in WAD format)
     */
    function setDecayRatePerSecond(
        uint256 newRatePerSecond
    ) external onlyOwner {
        if (!VotingDecayLibrary.isValidDecayRate(newRatePerSecond)) {
            revert InvalidDecayRate();
        }
        decayRatePerSecond = newRatePerSecond;
        emit IVotingDecayManager.DecayRateSet(newRatePerSecond);
    }

    /**
     * @notice Sets a new decay-free window duration
     * @param newWindow New decay-free window duration in seconds
     */
    function setDecayFreeWindow(uint40 newWindow) external onlyOwner {
        decayFreeWindow = newWindow;
        emit IVotingDecayManager.DecayFreeWindowSet(newWindow);
    }

    /**
     * @notice Sets a new decay function type
     * @param newFunction New decay function (Linear or Exponential)
     */
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external onlyOwner {
        decayFunction = newFunction;
        emit IVotingDecayManager.DecayFunctionSet(uint8(newFunction));
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
    ) public view returns (uint256) {
        uint256 decayFactor = getDecayFactor(accountAddress);

        return VotingDecayLibrary.applyDecay(originalValue, decayFactor);
    }

    /**
     * @notice Calculates the decay factor for an account
     * @param accountAddress Address to calculate retention factor for
     * @return Current retention factor
     */
    function getDecayFactor(
        address accountAddress
    ) public view returns (uint256) {
        address delegateTo = _getDelegateTo(accountAddress);

        // Has Delegate + Delegate has Decay Info
        if (
            delegateTo != address(0) &&
            delegateTo != accountAddress &&
            _hasDecayInfo(delegateTo)
        ) {
            return getDecayFactor(delegateTo);
        }

        // Has Delegate + Delegate does not have Decay Info
        // OR No Delegate + Does not have Decay Info
        if (!_hasDecayInfo(accountAddress)) {
            revert AccountNotInitialized();
        }

        // No Delegate + Has Decay Info
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;

        return
            VotingDecayLibrary.calculateDecayFactor(
                account.decayFactor,
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
    function getDecayInfo(
        address accountAddress
    ) public view returns (VotingDecayLibrary.DecayInfo memory) {
        return decayInfoByAccount[accountAddress];
    }

    /**
     * @notice Internal function to initialize an account if it's new
     * @param accountAddress Address of the account to initialize
     */
    function _initializeAccountIfNew(address accountAddress) internal {
        if (decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            decayInfoByAccount[accountAddress] = VotingDecayLibrary.DecayInfo({
                decayFactor: VotingDecayLibrary.WAD,
                lastUpdateTimestamp: uint40(block.timestamp)
            });
        }
    }

    function _hasDecayInfo(
        address accountAddress
    ) internal view returns (bool) {
        return decayInfoByAccount[accountAddress].lastUpdateTimestamp != 0;
    }

    /**
     * @notice Internal function to update the decay factor for an account
     * @param accountAddress Address of the account to update
     */
    function _updateDecayFactor(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        if (decayPeriod > decayFreeWindow) {
            uint256 newDecayFactor = getDecayFactor(accountAddress);
            account.decayFactor = newDecayFactor;
        }
        account.lastUpdateTimestamp = uint40(block.timestamp);

        emit IVotingDecayManager.DecayUpdated(
            accountAddress,
            account.decayFactor
        );
    }

    /**
     * @notice Internal function to reset the decay for an account
     * @param accountAddress Address of the account to reset
     */
    function _resetDecay(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        account.lastUpdateTimestamp = uint40(block.timestamp);
        account.decayFactor = VotingDecayLibrary.WAD;
        emit IVotingDecayManager.DecayReset(accountAddress);
    }

    function _getDelegateTo(
        address accountAddress
    ) internal view virtual returns (address);
}
