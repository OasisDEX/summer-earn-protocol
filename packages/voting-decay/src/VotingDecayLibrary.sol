// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {VotingDecayMath} from "./VotingDecayMath.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/*
 * @title VotingDecayLibrary
 * @notice A library for managing voting power decay in governance systems
 * @dev Utilizes VotingDecayMath for decay calculations
 */
library VotingDecayLibrary {
    using VotingDecayMath for uint256;
    using Checkpoints for Checkpoints.Trace224;

    /* @notice Constant representing 1 in the system's fixed-point arithmetic (18 decimal places) */
    uint256 private constant WAD = 1e18;

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
        uint40 originTimestamp;
        mapping(address => Checkpoints.Trace224) decayFactorCheckpoints;
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

    /**
     * @notice Maximum allowed depth for delegation chains to prevent recursion attacks
     * @dev When this depth is exceeded, voting power decays to 0 to maintain EIP-5805 invariants
     *      Example chain at max depth (2):
     *      User A -> delegates to B -> delegates to C (ok)
     *      User A -> delegates to B -> delegates to C -> delegates to D (returns 0)
     */
    uint256 public constant MAX_DELEGATION_DEPTH = 2;

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function initializeAccount(
        DecayState storage self,
        address accountAddress
    ) internal {
        _initializeAccount(self, accountAddress);
    }

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
     * @notice Updates the decay factor for an account and creates a checkpoint
     * @param self The DecayState storage
     * @param accountAddress The address of the account to update
     * @param getDelegateTo Function to retrieve delegation information
     */
    function updateDecayFactor(
        DecayState storage self,
        address accountAddress,
        function(address) view returns (address) getDelegateTo
    ) internal {
        _initializeAccount(self, accountAddress);
        DecayInfo storage account = self.decayInfoByAccount[accountAddress];

        uint256 decayPeriod = block.timestamp - account.lastUpdateTimestamp;
        uint256 newDecayFactor = account.decayFactor;

        if (decayPeriod > self.decayFreeWindow) {
            newDecayFactor = getDecayFactor(
                self,
                accountAddress,
                getDelegateTo
            );
        }

        // Create checkpoint with current timestamp and new decay factor
        self.decayFactorCheckpoints[accountAddress].push(
            uint32(block.timestamp),
            uint224(newDecayFactor)
        );

        account.decayFactor = newDecayFactor;
        account.lastUpdateTimestamp = uint40(block.timestamp);

        emit DecayUpdated(accountAddress, newDecayFactor);
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
        _initializeAccount(self, accountAddress);
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
        self.originTimestamp = uint40(block.timestamp);
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
    function _initializeAccount(
        DecayState storage self,
        address accountAddress
    ) private {
        if (self.decayInfoByAccount[accountAddress].lastUpdateTimestamp == 0) {
            self.decayInfoByAccount[accountAddress] = DecayInfo({
                decayFactor: WAD,
                lastUpdateTimestamp: uint40(block.timestamp)
            });

            self.decayFactorCheckpoints[accountAddress].push(
                uint32(block.timestamp),
                uint224(WAD)
            );

            emit AccountInitialized(accountAddress);
        }
    }

    /**
     * @notice Recursively calculates decay factor considering delegation depth
     * @dev Returns 0 in the following cases:
     *      1. When accountAddress is address(0)
     *      2. When delegation depth exceeds MAX_DELEGATION_DEPTH
     *      3. When the account or its delegate has no decay info
     * @param self The DecayState storage
     * @param accountAddress Current account being checked
     * @param depth Current delegation depth
     * @param originalAccount The initial account that started the calculation
     * @param getDelegateTo Function to retrieve delegation information
     * @return The calculated decay factor, or 0 if max depth exceeded
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
            return 0;
        }

        address delegateTo = getDelegateTo(accountAddress);

        // Detect cycles - if we're back to original account and within depth limit,
        // return the original account's decay factor
        if (delegateTo == originalAccount && depth > 0) {
            return _calculateAccountDecayFactor(self, originalAccount);
        }

        // Has Delegate + Delegate has Decay Info
        if (
            delegateTo != address(0) &&
            delegateTo != accountAddress &&
            hasDecayInfo(self, delegateTo)
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

        // For uninitialized accounts, calculate decay from contract origin
        if (!hasDecayInfo(self, accountAddress)) {
            return
                _calculateDecayFactor(
                    WAD,
                    block.timestamp - self.originTimestamp,
                    self.decayRatePerSecond,
                    self.decayFreeWindow,
                    self.decayFunction
                );
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
    function hasDecayInfo(
        DecayState storage self,
        address accountAddress
    ) internal view returns (bool) {
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

    /**
     * @notice Gets the length of a delegation chain for an account
     * @dev Counts the number of steps in the delegation chain until:
     *      1. A self-delegation is found
     *      2. An address(0) delegation is found
     *      3. MAX_DELEGATION_DEPTH is reached
     * @param self The DecayState storage
     * @param accountAddress The address to check delegation chain for
     * @param getDelegateTo Function to retrieve delegation information
     * @return uint256 The length of the delegation chain
     */
    function getDelegationChainLength(
        DecayState storage self,
        address accountAddress,
        function(address) view returns (address) getDelegateTo
    ) internal view returns (uint256) {
        return
            _getDelegationChainLengthWithDepth(
                self,
                accountAddress,
                0,
                accountAddress,
                getDelegateTo
            );
    }

    /**
     * @notice Internal recursive function to calculate delegation chain length
     * @param self The DecayState storage
     * @param accountAddress Current account being checked
     * @param depth Current depth in the delegation chain
     * @param originalAccount The initial account that started the calculation
     * @param getDelegateTo Function to retrieve delegation information
     * @return uint256 The length of the delegation chain
     */
    function _getDelegationChainLengthWithDepth(
        DecayState storage self,
        address accountAddress,
        uint256 depth,
        address originalAccount,
        function(address) view returns (address) getDelegateTo
    ) private view returns (uint256) {
        if (accountAddress == address(0)) {
            return 0;
        }

        address delegateTo = getDelegateTo(accountAddress);

        // Detect cycles by checking if we're back to the original account
        if (delegateTo == originalAccount) {
            return depth;
        }

        // Self-delegation or no delegation
        if (delegateTo == address(0) || delegateTo == accountAddress) {
            return depth;
        }

        // Continue counting if there's a valid delegation
        return
            _getDelegationChainLengthWithDepth(
                self,
                delegateTo,
                depth + 1,
                originalAccount,
                getDelegateTo
            );
    }

    /**
     * @notice Gets the historical decay factor for an account at a specific timestamp
     * @param self The DecayState storage
     * @param accountAddress The address to check
     * @param timestamp The timestamp to check at
     * @return The decay factor at that timestamp
     */
    function getHistoricalDecayFactor(
        DecayState storage self,
        address accountAddress,
        uint256 timestamp
    ) internal view returns (uint256) {
        if (timestamp < self.originTimestamp) {
            return 0;
        }

        uint224 checkpointValue = self
            .decayFactorCheckpoints[accountAddress]
            .upperLookup(uint32(timestamp));

        // No checkpoint found - calculate from origin
        if (checkpointValue == 0) {
            uint256 decayPeriod = timestamp - self.originTimestamp;

            if (decayPeriod <= self.decayFreeWindow) {
                return WAD;
            }

            // Apply decay from origin with WAD as base
            if (self.decayFunction == DecayFunction.Linear) {
                return
                    VotingDecayMath.linearDecay(
                        WAD,
                        self.decayRatePerSecond,
                        decayPeriod - self.decayFreeWindow
                    );
            } else if (self.decayFunction == DecayFunction.Exponential) {
                return
                    VotingDecayMath.exponentialDecay(
                        WAD,
                        self.decayRatePerSecond,
                        decayPeriod - self.decayFreeWindow
                    );
            } else {
                revert InvalidDecayType();
            }
        }
        // Checkpoint found - use it as base
        else {
            return uint256(checkpointValue);
        }
    }
}
