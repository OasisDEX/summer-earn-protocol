// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {VotingDecayLibrary} from "./VotingDecayLibrary.sol";

/**
 * @title IVotingDecayManager
 * @notice Interface for managing voting power decay in a governance system
 * @dev This interface defines the core functionality for a voting decay management system
 */
interface IVotingDecayManager {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidDecayRate();
    error AlreadyDelegated();
    error CannotDelegateToSelf();
    error NotDelegated();
    error NotAuthorizedToReset();
    error AccountNotInitialized();
    error MaxDelegationDepthExceeded();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event DecayUpdated(address indexed account, uint256 newRetentionFactor);
    event DecayRateSet(uint256 newRate);
    event DecayReset(address indexed account);
    event DecayFreeWindowSet(uint256 window);
    event DecayFunctionSet(uint8 newFunction);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function decayFreeWindow() external view returns (uint40);
    function decayRatePerSecond() external view returns (uint256);
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
     * @notice Sets a new decay rate per second
     * @param newRatePerSecond New decay rate (in WAD format)
     */
    function setDecayRatePerSecond(uint256 newRatePerSecond) external;

    /**
     * @notice Sets a new decay-free window duration
     * @param newWindow New decay-free window duration in seconds
     */
    function setDecayFreeWindow(uint40 newWindow) external;

    /**
     * @notice Sets a new decay function type
     * @param newFunction New decay function (Linear or Exponential)
     */
    function setDecayFunction(
        VotingDecayLibrary.DecayFunction newFunction
    ) external;

    /**
     * @notice Calculates the decay factor for an account
     * @param accountAddress Address to calculate retention factor for
     * @return Current retention factor
     */
    function getDecayFactor(
        address accountAddress
    ) external view returns (uint256);

    /**
     * @notice Gets the decay information for an account
     * @param accountAddress Address to get decay info for
     * @return DecayInfo struct containing decay information
     */
    function getDecayInfo(
        address accountAddress
    ) external view returns (VotingDecayLibrary.DecayInfo memory);
}
