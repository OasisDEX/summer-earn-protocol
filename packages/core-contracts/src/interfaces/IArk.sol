// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IArkAccessManaged} from "./IArkAccessManaged.sol";
import "../types/Percentage.sol";
import "../types/ArkTypes.sol";
import "../events/IArkEvents.sol";

/**
 * @title IArk
 * @notice Interface for the Ark contract, which manages funds and interacts with Rafts
 * @dev Inherits from IArkAccessManaged for access control and IArkEvents for event definitions
 */
interface IArk is IArkAccessManaged, IArkEvents {
    /* FUNCTIONS - PUBLIC */

    /**
     * @notice Returns the maximum allocation for this Ark
     * @return The maximum allocation amount
     */
    function maxAllocation() external view returns (uint256);

    /**
     * @notice Returns the current underlying balance of the Ark
     * @return The total assets in the Ark, in token precision
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Returns the current rate of the Ark
     * @return The current rate in RAY precision
     */
    function rate() external view returns (uint256);

    /**
     * @notice Returns the address of the Fleet commander managing the ark
     * @return address Address of Fleet commander managing the ark if a Commander is assigned, address(0) otherwise
     */
    function commander() external view returns (address);

    /**
     * @notice Updates information about the Ark
     */
    function poke() external;

    /**
     * @notice Triggers a harvest operation to collect rewards
     */
    function harvest() external;

    /* FUNCTIONS - EXTERNAL - COMMANDER */

    /**
     * @notice Deposits (boards) tokens into the Ark
     * @param amount The amount of tokens to deposit
     */
    function board(uint256 amount) external;

    /**
     * @notice Withdraws (disembarks) tokens from the Ark
     * @param amount The amount of tokens to withdraw
     * @param receiver Address receiving the withdrawn funds
     */
    function disembark(uint256 amount, address receiver) external;

    /**
     * @notice Sets a new maximum allocation for the Ark
     * @param newMaxAllocation The new maximum allocation amount
     */
    function setMaxAllocation(uint256 newMaxAllocation) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */

    /**
     * @notice Sets a new Raft address for the Ark
     * @param newRaft The address of the new Raft
     */
    function setRaft(address newRaft) external;

    error InvalidVaultAddress();
}
