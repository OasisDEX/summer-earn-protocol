// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VotingDecayLibrary} from "./VotingDecayLibrary.sol";
import {IVotingDecayManager} from "./IVotingDecayManager.sol";

/**
 * @title VotingDecayManager
 * @notice Manages voting power decay for accounts in a governance system
 * @dev Implements decay calculations, delegation, and administrative functions
 */
abstract contract VotingDecayManager is IVotingDecayManager {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of account addresses to their decay information
    mapping(address account => VotingDecayLibrary.DecayInfo info)
        internal decayInfoByAccount;

    /// @notice Duration in seconds during which no decay is applied
    uint40 public decayFreeWindow;

    /// @notice Rate at which voting power decays per second after the decay-free window
    uint256 public decayRatePerSecond;

    /// @notice Type of mathematical function used to calculate decay
    VotingDecayLibrary.DecayFunction public decayFunction;

    /// @notice Maximum allowed depth for delegation chains to prevent circular dependencies
    uint256 private constant MAX_DELEGATION_DEPTH = 1;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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
    ) {
        decayFreeWindow = decayFreeWindow_;
        decayRatePerSecond = decayRatePerSecond_;
        decayFunction = decayFunction_;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
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

    /**
     * @notice Sets a new decay rate per second
     * @param newRatePerSecond New decay rate (in WAD format)
     */
    function _setDecayRatePerSecond(uint256 newRatePerSecond) internal virtual {
        if (!VotingDecayLibrary.isValidDecayRate(newRatePerSecond)) {
            revert InvalidDecayRate();
        }
        decayRatePerSecond = newRatePerSecond;
        emit DecayRateSet(newRatePerSecond);
    }

    /**
     * @notice Sets a new decay-free window duration
     * @param newWindow New decay-free window duration in seconds
     */
    function _setDecayFreeWindow(uint40 newWindow) internal virtual {
        decayFreeWindow = newWindow;
        emit DecayFreeWindowSet(newWindow);
    }

    /**
     * @notice Sets a new decay function type
     * @param newFunction New decay function (Linear or Exponential)
     */
    function _setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) internal virtual {
        decayFunction = newFunction;
        emit DecayFunctionSet(uint8(newFunction));
    }

    /**
     * @notice Initializes an account's decay information if it doesn't exist
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

    /**
     * @notice Checks if an account has decay information initialized
     * @param accountAddress Address of the account to check
     * @return bool True if the account has decay information, false otherwise
     */
    function _hasDecayInfo(
        address accountAddress
    ) internal view returns (bool) {
        return decayInfoByAccount[accountAddress].lastUpdateTimestamp != 0;
    }

    /**
     * @notice Updates the decay factor for an account
     * @param accountAddress Address of the account to update
     * @dev Updates the decay factor if the decay-free window has passed and resets the timestamp
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

        emit DecayUpdated(accountAddress, account.decayFactor);
    }

    /**
     * @notice Resets an account's decay factor to WAD (1e18) and updates the timestamp
     * @param accountAddress Address of the account to reset
     */
    function _resetDecay(address accountAddress) internal {
        _initializeAccountIfNew(accountAddress);
        VotingDecayLibrary.DecayInfo storage account = decayInfoByAccount[
            accountAddress
        ];
        account.lastUpdateTimestamp = uint40(block.timestamp);
        account.decayFactor = VotingDecayLibrary.WAD;
        emit DecayReset(accountAddress);
    }

    /**
     * @notice Gets the delegate address for a given account
     * @param accountAddress Address of the account to check delegation for
     * @return address The delegate address, or zero address if no delegation
     * @dev This function must be implemented by inheriting contracts
     */
    function _getDelegateTo(
        address accountAddress
    ) internal view virtual returns (address);
}
