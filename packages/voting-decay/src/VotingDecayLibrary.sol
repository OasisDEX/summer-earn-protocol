// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VotingDecayMath} from "./VotingDecayMath.sol";

/*
 * @title VotingDecayLibrary
 * @notice A library for managing voting power decay in governance systems
 * @dev Utilizes VotingDecayMath for decay calculations
 */
library VotingDecayLibrary {
    using VotingDecayMath for uint256;

    /* @notice Constant representing 1 in the system's fixed-point arithmetic (18 decimal places) */
    uint256 public constant WAD = 1e18;

    /* @notice Number of seconds in a year, used for annualized rate calculations */
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /* @notice Enumeration of supported decay function types */
    enum DecayFunction {
        Linear,
        Exponential
    }

    /*
     * @notice Structure to store decay information for an account
     * @param decayFactor The current decay factor of the account's voting power
     * @param lastUpdateTimestamp The timestamp of the last update to the account's decay info
     */
    struct DecayInfo {
        uint256 decayFactor;
        uint40 lastUpdateTimestamp;
    }

    struct DecayState {
        mapping(address => DecayInfo) decayInfoByAccount;
        uint40 decayFreeWindow;
        uint256 decayRatePerSecond;
        DecayFunction decayFunction;
    }

    /**
     * @notice Thrown when the decay type is invalid
     */
    error InvalidDecayType();

    // Events
    event DecayRateSet(uint256 newRate);
    event DecayFreeWindowSet(uint40 newWindow);
    event DecayFunctionSet(uint8 newFunction);
    event AccountInitialized(address account);
    event DecayUpdated(address account, uint256 newDecayFactor);
    event DecayReset(address account);

    // Errors
    error AccountNotInitialized();
    error InvalidDecayRate();

    uint256 private constant MAX_DELEGATION_DEPTH = 2;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the current decay factor for an account, considering delegation
     * @param self The DecayState storage
     * @param accountAddress The address of the account to check
     * @param getDelegateTo Function to retrieve delegation information
     * @return The current decay factor for the account
     */
    function getDecayFactor(
        DecayState storage self,
        address accountAddress,
        function(address) view returns (address) getDelegateTo
    ) internal view returns (uint256) {
        return
            _getDecayFactorWithDepth(
                self,
                accountAddress,
                0,
                accountAddress,
                getDelegateTo
            );
    }

    /**
     * @notice Retrieves the decay info for a specific account
     * @param self The DecayState storage
     * @param accountAddress The address of the account
     * @return DecayInfo struct containing the account's decay information
     */
    function getDecayInfo(
        DecayState storage self,
        address accountAddress
    ) internal view returns (DecayInfo memory) {
        return self.decayInfoByAccount[accountAddress];
    }

    /**
     * @notice Sets the decay rate per second
     * @param self The DecayState storage
     * @param newRatePerSecond The new decay rate to set
     */
    function setDecayRatePerSecond(
        DecayState storage self,
        uint256 newRatePerSecond
    ) internal {
        if (!isValidDecayRate(newRatePerSecond)) {
            revert InvalidDecayRate();
        }
        self.decayRatePerSecond = newRatePerSecond;
        emit DecayRateSet(newRatePerSecond);
    }

    /**
     * @notice Sets the decay-free window period during which no decay occurs
     * @param self The DecayState storage
     * @param newWindow The new decay-free window duration in seconds
     */
    function setDecayFreeWindow(
        DecayState storage self,
        uint40 newWindow
    ) internal {
        self.decayFreeWindow = newWindow;
        emit DecayFreeWindowSet(newWindow);
    }

    /**
     * @notice Sets the decay function type (Linear or Exponential)
     * @param self The DecayState storage
     * @param newFunction The new decay function to use
     */
    function setDecayFunction(
        DecayState storage self,
        DecayFunction newFunction
    ) internal {
        self.decayFunction = newFunction;
        emit DecayFunctionSet(uint8(newFunction));
    }

    /**
     * @notice Updates the decay factor for an account, considering the decay-free window
     * @param self The DecayState storage
     * @param accountAddress The address of the account to update
     * @param getDelegateTo Function to retrieve delegation information
     */
    function updateDecayFactor(
        DecayState storage self,
        address accountAddress,
        function(address) view returns (address) getDelegateTo
    ) internal {
        _initializeAccountIfNew(self, accountAddress);
        DecayInfo storage account = self.decayInfoByAccount[accountAddress];

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        if (decayPeriod > self.decayFreeWindow) {
            uint256 newDecayFactor = getDecayFactor(
                self,
                accountAddress,
                getDelegateTo
            );
            account.decayFactor = newDecayFactor;
        }
        account.lastUpdateTimestamp = uint40(block.timestamp);

        emit DecayUpdated(accountAddress, account.decayFactor);
    }

    /**
     * @notice Resets the decay factor for an account back to WAD (1e18)
     * @param self The DecayState storage
     * @param accountAddress The address of the account to reset
     */
    function resetDecay(
        DecayState storage self,
        address accountAddress
    ) internal {
        _initializeAccountIfNew(self, accountAddress);
        DecayInfo storage account = self.decayInfoByAccount[accountAddress];
        account.lastUpdateTimestamp = uint40(block.timestamp);
        account.decayFactor = WAD;
        emit DecayReset(accountAddress);
    }

    /**
     * @notice Initializes the decay state with initial parameters
     * @param self The DecayState storage
     * @param decayFreeWindow_ The initial decay-free window duration in seconds
     * @param decayRatePerSecond_ The initial decay rate per second
     * @param decayFunction_ The initial decay function type
     */
    function initialize(
        DecayState storage self,
        uint40 decayFreeWindow_,
        uint256 decayRatePerSecond_,
        DecayFunction decayFunction_
    ) internal {
        self.decayFreeWindow = decayFreeWindow_;
        self.decayRatePerSecond = decayRatePerSecond_;
        self.decayFunction = decayFunction_;
    }

    /**
     * @notice Calculates the current voting power by applying decay to the original value
     * @param self The DecayState storage
     * @param accountAddress The address of the account
     * @param originalValue The original voting power value before decay
     * @param getDelegateTo Function to retrieve delegation information
     * @return The current voting power after applying decay
     */
    function getVotingPower(
        DecayState storage self,
        address accountAddress,
        uint256 originalValue,
        function(address) view returns (address) getDelegateTo
    ) internal view returns (uint256) {
        uint256 decayFactor = getDecayFactor(
            self,
            accountAddress,
            getDelegateTo
        );
        return applyDecay(originalValue, decayFactor);
    }

    /*
     * @notice Applies the decay to the original voting power value
     * @param originalValue The original voting power value
     * @param retentionFactor The current retention factor
     * @return The decayed voting power value
     */
    function applyDecay(
        uint256 originalValue,
        uint256 retentionFactor
    ) internal pure returns (uint256) {
        return VotingDecayMath.mulDiv(originalValue, retentionFactor, WAD);
    }

    /*
     * @notice Checks if a given decay rate is valid
     * @param rate The decay rate to check
     * @return A boolean indicating whether the rate is valid (less than or equal to WAD)
     */
    function isValidDecayRate(uint256 rate) internal pure returns (bool) {
        return rate <= WAD;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes decay information for an account if it hasn't been initialized before
     * @dev Sets initial decay factor to WAD (1e18) and lastUpdateTimestamp to current block timestamp
     * @param self The DecayState storage
     * @param accountAddress The address of the account to initialize
     * @custom:emits AccountInitialized when a new account is initialized
     */
    function _initializeAccountIfNew(
        DecayState storage self,
        address accountAddress
    ) private {
        if (self.decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            self.decayInfoByAccount[accountAddress] = DecayInfo({
                decayFactor: WAD,
                lastUpdateTimestamp: uint40(block.timestamp)
            });

            emit AccountInitialized(accountAddress);
        }
    }

    /**
     * @notice Recursively calculates decay factor considering delegation depth
     * @param self The DecayState storage
     * @param accountAddress Current account being checked
     * @param depth Current delegation depth
     * @param originalAccount The initial account that started the calculation
     * @param getDelegateTo Function to retrieve delegation information
     * @return The calculated decay factor
     */
    function _getDecayFactorWithDepth(
        DecayState storage self,
        address accountAddress,
        uint256 depth,
        address originalAccount,
        function(address) view returns (address) getDelegateTo
    ) private view returns (uint256) {
        if (accountAddress == address(0)) {
            return 0;
        }

        if (depth >= MAX_DELEGATION_DEPTH) {
            return _calculateAccountDecayFactor(self, originalAccount);
        }

        address delegateTo = getDelegateTo(accountAddress);

        // Has Delegate + Delegate has Decay Info
        if (
            delegateTo != address(0) &&
            delegateTo != accountAddress &&
            _hasDecayInfo(self, delegateTo)
        ) {
            return
                _getDecayFactorWithDepth(
                    self,
                    delegateTo,
                    depth + 1,
                    originalAccount,
                    getDelegateTo
                );
        }

        // Has Delegate + Delegate does not have Decay Info
        // OR No Delegate + Does not have Decay Info
        if (!_hasDecayInfo(self, accountAddress)) {
            return 0;
        }

        // No Delegate + Has Decay Info
        return _calculateAccountDecayFactor(self, accountAddress);
    }

    /**
     * @notice Calculates the current decay factor for an account
     * @param self The DecayState storage
     * @param accountAddress The address of the account
     * @return The calculated decay factor
     */
    function _calculateAccountDecayFactor(
        DecayState storage self,
        address accountAddress
    ) private view returns (uint256) {
        DecayInfo storage account = self.decayInfoByAccount[accountAddress];
        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        return
            _calculateDecayFactor(
                account.decayFactor,
                decayPeriod,
                self.decayRatePerSecond,
                self.decayFreeWindow,
                self.decayFunction
            );
    }

    /**
     * @notice Checks if an account has decay information initialized
     * @param self The DecayState storage
     * @param accountAddress The address to check
     * @return bool True if the account has decay info, false otherwise
     */
    function _hasDecayInfo(
        DecayState storage self,
        address accountAddress
    ) private view returns (bool) {
        return self.decayInfoByAccount[accountAddress].lastUpdateTimestamp != 0;
    }

    /*
     * @notice Calculates the new decay factor based on elapsed time and decay parameters
     * @param currentDecayFactor The current retention factor
     * @param elapsedSeconds The number of seconds elapsed since the last update
     * @param decayRatePerSecond The decay rate per second
     * @param decayFreeWindow The duration (in seconds) during which no decay occurs
     * @param decayFunction The type of decay function to use (Linear or Exponential)
     * @return The newly calculated retention factor
     */
    function _calculateDecayFactor(
        uint256 currentDecayFactor,
        uint256 elapsedSeconds,
        uint256 decayRatePerSecond,
        uint256 decayFreeWindow,
        DecayFunction decayFunction
    ) private pure returns (uint256) {
        if (elapsedSeconds <= decayFreeWindow) return currentDecayFactor;

        uint256 decayTime = elapsedSeconds - decayFreeWindow;

        if (decayFunction == DecayFunction.Linear) {
            return
                currentDecayFactor.linearDecay(decayRatePerSecond, decayTime);
        } else if (decayFunction == DecayFunction.Exponential) {
            return
                currentDecayFactor.exponentialDecay(
                    decayRatePerSecond,
                    decayTime
                );
        } else {
            revert InvalidDecayType();
        }
    }
}
