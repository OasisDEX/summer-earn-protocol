// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VotingDecayLibrary} from "./VotingDecayLibrary.sol";
import {IVotingDecayManager} from "./IVotingDecayManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingDecayManager
 * @notice Manages voting power decay for accounts in a governance system
 * @dev Implements decay calculations, delegation, and administrative functions
 */
abstract contract VotingDecayManager is IVotingDecayManager, Ownable {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address account => VotingDecayLibrary.DecayInfo info)
        internal decayInfoByAccount;

    uint40 public decayFreeWindow;
    uint256 public decayRatePerSecond;
    VotingDecayLibrary.DecayFunction public decayFunction;

    uint256 private constant MAX_DELEGATION_DEPTH = 1;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to initialize the VotingDecayManager
     * @param decayFreeWindow_ Initial decay-free window duration
     * @param decayRatePerSecond_ Initial decay rate per second
     * @param decayFunction_ Initial decay function type
     * @param owner_ Initial owner of the contract
     */
    constructor(
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        VotingDecayLibrary.DecayFunction decayFunction_,
        address owner_
    ) Ownable(owner_) {
        decayFreeWindow = decayFreeWindow_;
        decayRatePerSecond = decayRatePerSecond_;
        decayFunction = decayFunction_;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingDecayManager
    function setDecayRatePerSecond(
        uint256 newRatePerSecond
    ) external onlyOwner {
        if (!VotingDecayLibrary.isValidDecayRate(newRatePerSecond)) {
            revert InvalidDecayRate();
        }
        decayRatePerSecond = newRatePerSecond;
        emit DecayRateSet(newRatePerSecond);
    }

    /// @inheritdoc IVotingDecayManager
    function setDecayFreeWindow(uint40 newWindow) external onlyOwner {
        decayFreeWindow = newWindow;
        emit DecayFreeWindowSet(newWindow);
    }

    /// @inheritdoc IVotingDecayManager
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external onlyOwner {
        decayFunction = newFunction;
        emit DecayFunctionSet(uint8(newFunction));
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingDecayManager
    function getVotingPower(
        address accountAddress,
        uint256 originalValue
    ) public view returns (uint256) {
        uint256 decayFactor = getDecayFactor(accountAddress);
        return VotingDecayLibrary.applyDecay(originalValue, decayFactor);
    }

    /// @inheritdoc IVotingDecayManager
    function getDecayFactor(
        address accountAddress
    ) public view returns (uint256) {
        return _getDecayFactorWithDepth(accountAddress, 0);
    }

    function _getDecayFactorWithDepth(
        address accountAddress,
        uint256 depth
    ) private view returns (uint256) {
        if (depth >= MAX_DELEGATION_DEPTH) {
            revert MaxDelegationDepthExceeded();
        }

        address delegateTo = _getDelegateTo(accountAddress);

        // Has Delegate + Delegate has Decay Info
        if (
            delegateTo != address(0) &&
            delegateTo != accountAddress &&
            _hasDecayInfo(delegateTo)
        ) {
            return _getDecayFactorWithDepth(delegateTo, depth + 1);
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

    /// @inheritdoc IVotingDecayManager
    function getDecayInfo(
        address accountAddress
    ) public view returns (VotingDecayLibrary.DecayInfo memory) {
        return decayInfoByAccount[accountAddress];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

        emit DecayUpdated(accountAddress, account.decayFactor);
    }

    function _resetDecay(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        account.lastUpdateTimestamp = uint40(block.timestamp);
        account.decayFactor = VotingDecayLibrary.WAD;
        emit DecayReset(accountAddress);
    }

    function _getDelegateTo(
        address accountAddress
    ) internal view virtual returns (address);
}
