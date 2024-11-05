// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VotingDecayLibrary} from "./VotingDecayLibrary.sol";
import {IVotingDecayManager} from "./IVotingDecayManager.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title VotingDecayManager
 * @notice Manages voting power decay for accounts in a governance system
 * @dev Implements decay calculations, delegation, and administrative functions
 */
abstract contract VotingDecayManager is IVotingDecayManager {
    using VotingDecayLibrary for VotingDecayLibrary.DecayInfo;
    using Checkpoints for Checkpoints.Trace208;

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
    uint256 private constant MAX_DELEGATION_DEPTH = 2;

    /// @notice Mapping of account addresses to their decay factor checkpoints
    mapping(address => Checkpoints.Trace208) private _decayFactorCheckpoints;

    /// @notice Mapping of account addresses to their last update checkpoints
    mapping(address => Checkpoints.Trace208) private _lastUpdateCheckpoints;

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
        return _getDecayFactorWithDepth(accountAddress, 0, accountAddress);
    }

    function _getDecayFactorWithDepth(
        address accountAddress,
        uint256 depth,
        address originalAccount
    ) private view returns (uint256) {
        if (depth >= MAX_DELEGATION_DEPTH) {
            return _calculateDecayFactor(originalAccount);
        }

        address delegateTo = _getDelegateTo(accountAddress);

        // Has Delegate + Delegate has Decay Info
        if (
            delegateTo != address(0) &&
            delegateTo != accountAddress &&
            _hasDecayInfo(delegateTo)
        ) {
            return
                _getDecayFactorWithDepth(
                    delegateTo,
                    depth + 1,
                    originalAccount
                );
        }

        // Has Delegate + Delegate does not have Decay Info
        // OR No Delegate + Does not have Decay Info
        if (!_hasDecayInfo(accountAddress)) {
            revert AccountNotInitialized();
        }

        // No Delegate + Has Decay Info
        return _calculateDecayFactor(accountAddress);
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

    function _calculateDecayFactor(
        address accountAddress
    ) internal view returns (uint256) {
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

            emit AccountInitialized(accountAddress);
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
    function _updateDecayFactor(address accountAddress) internal virtual {
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

        // Create checkpoint after updating
        _writeDecaySnapshot(accountAddress);
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

    function _writeDecaySnapshot(address account) internal {
        VotingDecayLibrary.DecayInfo storage currentInfo = decayInfoByAccount[
            account
        ];

        _decayFactorCheckpoints[account].push(
            uint48(block.number),
            SafeCast.toUint208(currentInfo.decayFactor)
        );

        _lastUpdateCheckpoints[account].push(
            uint48(block.number),
            SafeCast.toUint208(currentInfo.lastUpdateTimestamp)
        );
    }

    function _getDecayInfoAtTimepoint(
        address account,
        uint256 timepoint
    ) internal view returns (uint256 decayFactor, uint256 lastUpdateTimestamp) {
        uint48 blockNumber = SafeCast.toUint48(timepoint);

        decayFactor = _decayFactorCheckpoints[account].upperLookupRecent(
            blockNumber
        );
        lastUpdateTimestamp = _lastUpdateCheckpoints[account].upperLookupRecent(
            blockNumber
        );
    }

    /**
     * @notice Calculates the historical decay factor at a specific timepoint
     * @param account Address of the account
     * @param timepoint The block number to calculate for
     * @return The decay factor at that timepoint
     */
    function _calculateHistoricalDecayFactor(
        address account,
        uint256 timepoint
    ) internal view returns (uint256) {
        (
            uint256 historicalDecayFactor,
            uint256 historicalLastUpdate
        ) = _getDecayInfoAtTimepoint(account, timepoint);

        uint256 decayPeriod = timepoint - historicalLastUpdate;
        return
            VotingDecayLibrary.calculateDecayFactor(
                historicalDecayFactor,
                decayPeriod,
                decayRatePerSecond,
                decayFreeWindow,
                decayFunction
            );
    }
}
