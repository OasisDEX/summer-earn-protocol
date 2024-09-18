// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VotingDecayLibrary} from "./VotingDecayLibrary.sol";

/**
 * @title IVotingDecayManager
 * @notice Interface for managing voting power decay in a governance system
 * @dev This interface defines the core functionality for a voting decay management system
 */
interface IVotingDecayManager {
    /* Errors */

    /**
     * @notice Thrown when an invalid decay rate is set
     */
    error InvalidDecayRate();

    /**
     * @notice Thrown when trying to delegate voting power that's already delegated
     */
    error AlreadyDelegated();

    /**
     * @notice Thrown when attempting to delegate voting power to oneself
     */
    error CannotDelegateToSelf();

    /**
     * @notice Thrown when trying to undelegate voting power that isn't delegated
     */
    error NotDelegated();

    /**
     * @notice Thrown when an unauthorized address attempts to reset decay
     */
    error NotAuthorizedToReset();

    /**
     * @notice Thrown when trying to perform an operation on an uninitialized account
     */
    error AccountNotInitialized();

    /* Events */

    /**
     * @notice Emitted when an account's decay factor is updated
     * @param account The address of the account whose decay factor was updated
     * @param newRetentionFactor The new retention factor after the update
     */
    event DecayUpdated(address indexed account, uint256 newRetentionFactor);

    /**
     * @notice Emitted when the global decay rate is changed
     * @param newRate The new decay rate
     */
    event DecayRateSet(uint256 newRate);

    /**
     * @notice Emitted when an account's decay is reset to its initial state
     * @param account The address of the account whose decay was reset
     */
    event DecayReset(address indexed account);

    /**
     * @notice Emitted when the decay-free window duration is changed
     * @param window The new duration of the decay-free window
     */
    event DecayFreeWindowSet(uint256 window);

    /**
     * @notice Emitted when the decay function type is changed
     * @param newFunction The new decay function type (0 for Linear, 1 for Exponential)
     */
    event DecayFunctionSet(uint8 newFunction);

    /* Function Declarations */

    /**
     * @notice Returns the current decay-free window duration
     * @return The decay-free window duration in seconds
     */
    function decayFreeWindow() external view returns (uint40);

    /**
     * @notice Returns the current decay rate per second
     * @return The decay rate per second
     */
    function decayRatePerSecond() external view returns (uint256);

    /**
     * @notice Returns the current decay function type
     * @return The current decay function (Linear or Exponential)
     */
    function decayFunction()
        external
        view
        returns (VotingDecayLibrary.DecayFunction);

    /**
     * @notice Calculates the current voting power for an account
     * @dev This function applies the decay factor to the original voting power
     * @param accountAddress The address of the account to calculate voting power for
     * @param originalValue The original voting power value before decay
     * @return The current voting power after applying decay
     */
    function getVotingPower(
        address accountAddress,
        uint256 originalValue
    ) external view returns (uint256);

    /**
     * @notice Sets the global decay rate
     * @dev This function should only be callable by authorized addresses
     * @param newRate The new decay rate to set
     */
    function setDecayRate(uint256 newRate) external;

    /**
     * @notice Sets the decay-free window duration
     * @dev This function should only be callable by authorized addresses
     * @param window The new duration of the decay-free window in seconds
     */
    function setDecayFreeWindow(uint40 window) external;

    /**
     * @notice Sets the decay function type
     * @dev This function should only be callable by authorized addresses
     * @param newFunction The new decay function type (0 for Linear, 1 for Exponential)
     */
    function setDecayFunction(uint8 newFunction) external;

    /**
     * @notice Resets the decay for a specific account
     * @dev This function should only be callable by authorized addresses
     * @param account The address of the account to reset decay for
     */
    function resetDecay(address account) external;

    /**
     * @notice Initializes an account in the voting decay system
     * @dev This function should be called before an account can participate in voting
     * @param account The address of the account to initialize
     */
    function initializeAccount(address account) external;

    /**
     * @notice Checks if an account has been initialized in the voting decay system
     * @param account The address of the account to check
     * @return A boolean indicating whether the account is initialized
     */
    function isInitialized(address account) external view returns (bool);

    /**
     * @notice Returns the last update timestamp for an account
     * @param account The address of the account to query
     * @return The timestamp of the last update for the account
     */
    function lastUpdateTimestamp(
        address account
    ) external view returns (uint40);

    /**
     * @notice Returns the current retention factor for an account
     * @dev The retention factor represents the percentage of voting power retained after decay
     * @param account The address of the account to query
     * @return The current retention factor for the account
     */
    function retentionFactor(address account) external view returns (uint256);
}
