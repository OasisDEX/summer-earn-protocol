// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ITipJar} from "../interfaces/ITipJar.sol";

import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {ConfigurationManaged} from "./ConfigurationManaged.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {Constants} from "@summerfi/constants/Constants.sol";
import {PERCENTAGE_100, Percentage, fromPercentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
/**
 * @title TipJar
 * @notice Manages tip streams for distributing rewards from FleetCommanders
 * @dev Implements ITipJar interface and inherits from ProtocolAccessManaged and ConfigurationManaged
 * @custom:see ITipJar
 */

contract TipJar is
    ITipJar,
    ProtocolAccessManaged,
    ConfigurationManaged,
    Pausable
{
    using SafeERC20 for IERC20;
    using PercentageUtils for uint256;

    /// @notice The maximum duration that a tip stream can be locked for
    uint256 constant MAX_ALLOWED_LOCKED_UNTIL_EPOCH = 750 days;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of recipient addresses to their TipStream structs
    mapping(address recipient => TipStream tipStream) public tipStreams;

    /// @notice List of all tip stream recipient addresses
    address[] public tipStreamRecipients;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the TipJar contract
     * @param _accessManager The address of the access manager contract
     * @param _configurationManager The address of the configuration manager contract
     */
    constructor(
        address _accessManager,
        address _configurationManager
    )
        ProtocolAccessManaged(_accessManager)
        ConfigurationManaged(_configurationManager)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITipJar
    function addTipStream(
        TipStream memory tipStream
    ) external onlyGovernor returns (uint256 lockedUntilEpoch) {
        // Add check for zero address
        if (tipStream.recipient == address(0)) {
            revert InvalidTipStreamRecipient();
        }
        if (tipStreams[tipStream.recipient].recipient != address(0)) {
            revert TipStreamAlreadyExists(tipStream.recipient);
        }
        if (
            tipStream.lockedUntilEpoch >
            block.timestamp + MAX_ALLOWED_LOCKED_UNTIL_EPOCH
        ) {
            revert TipStreamLockedForTooLong(tipStream.recipient);
        }
        _validateTipStreamAllocation(tipStream.allocation, toPercentage(0));

        // The allocation in TipStream uses the Percentage type from @summerfi/percentage-solidity
        // Percentages have 18 decimals of precision
        // For example, 1% would be represented as 1 * 10^18 (assuming PERCENTAGE_DECIMALS is 18)
        tipStreams[tipStream.recipient] = tipStream;
        tipStreamRecipients.push(tipStream.recipient);

        emit TipStreamAdded(tipStream);

        return tipStream.lockedUntilEpoch;
    }

    /// @inheritdoc ITipJar
    function removeTipStream(address recipient) external onlyGovernor {
        _validateTipStream(recipient);

        delete tipStreams[recipient];
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            if (tipStreamRecipients[i] == recipient) {
                tipStreamRecipients[i] = tipStreamRecipients[
                    tipStreamRecipients.length - 1
                ];
                tipStreamRecipients.pop();
                break;
            }
        }

        emit TipStreamRemoved(recipient);
    }

    /// @notice It's good practice to call _shake for all fleet commanders
    /// before updating a tip stream to ensure all accumulated rewards
    /// are distributed using the current allocation.
    /// @dev Warning: A global shake can be gas expensive if there are many fleet commanders
    /// @inheritdoc ITipJar
    function updateTipStream(
        TipStream memory tipStream,
        bool shakeAllFleetCommanders
    ) external onlyGovernor {
        _validateTipStream(tipStream.recipient);
        TipStream memory oldTipStream = tipStreams[tipStream.recipient];
        Percentage currentAllocation = oldTipStream.allocation;
        _validateTipStreamAllocation(tipStream.allocation, currentAllocation);

        if (shakeAllFleetCommanders) {
            shakeAll();
        }
        if (
            tipStream.lockedUntilEpoch >
            block.timestamp + MAX_ALLOWED_LOCKED_UNTIL_EPOCH
        ) {
            revert TipStreamLockedForTooLong(tipStream.recipient);
        }
        tipStreams[tipStream.recipient].allocation = tipStream.allocation;
        tipStreams[tipStream.recipient].lockedUntilEpoch = tipStream
            .lockedUntilEpoch;

        emit TipStreamUpdated(oldTipStream, tipStream);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITipJar
    function shake(address fleetCommander_) external whenNotPaused {
        _shake(fleetCommander_);
    }

    /// @inheritdoc ITipJar
    function shakeMultiple(address[] calldata fleetCommanders) external {
        _shakeMultiple(fleetCommanders);
    }

    /// @notice Shakes all active fleet commanders
    /// @dev This function can be called to distribute rewards from all active fleet commanders
    /// @dev Warning: This operation can be gas expensive if there are many fleet commanders
    function shakeAll() public {
        address[] memory activeFleetCommanders = IHarborCommand(harborCommand())
            .getActiveFleetCommanders();
        _shakeMultiple(activeFleetCommanders);
    }

    /**
     * @inheritdoc ITipJar
     * @dev Only callable by addresses with the GUARDIAN_ROLE
     */
    function pause() external onlyGuardian {
        _pause();
        emit TipJarPaused(msg.sender);
    }

    /**
     * @inheritdoc ITipJar
     * @dev Only callable by addresses with the GOVERNOR_ROLE
     */
    function unpause() external onlyGovernor {
        _unpause();
        emit TipJarUnpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITipJar
    function getTipStream(
        address recipient
    ) external view returns (TipStream memory) {
        return tipStreams[recipient];
    }

    /// @inheritdoc ITipJar
    function getAllTipStreams()
        external
        view
        returns (TipStream[] memory allStreams)
    {
        allStreams = new TipStream[](tipStreamRecipients.length);
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            allStreams[i] = tipStreams[tipStreamRecipients[i]];
        }
    }

    /// @inheritdoc ITipJar
    function getTotalAllocation() public view returns (Percentage total) {
        total = toPercentage(0);
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            total = total + tipStreams[tipStreamRecipients[i]].allocation;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Distributes accumulated tips from a single FleetCommander
     * @param fleetCommander_ The address of the FleetCommander contract to distribute tips from
     * @custom:internal-logic
     * - Verifies if the provided FleetCommander address is active
     * - Retrieves the TipJar's balance of shares from the FleetCommander
     * - Redeems the shares for underlying assets
     * - Distributes the assets to tip stream recipients based on their allocations
     * - Transfers any remaining balance to the treasury
     * @custom:effects
     * - Redeems shares from the FleetCommander
     * - Transfers assets to tip stream recipients and treasury
     * - Emits a TipJarShaken event
     * @custom:security-considerations
     * - Ensures the FleetCommander is active before processing
     * - Handles potential rounding errors in asset distribution
     * - Verifies there are shares to redeem and assets to distribute
     */
    function _shake(address fleetCommander_) internal {
        if (
            !IHarborCommand(harborCommand()).activeFleetCommanders(
                fleetCommander_
            )
        ) {
            revert InvalidFleetCommanderAddress();
        }

        IFleetCommander fleetCommander = IFleetCommander(fleetCommander_);

        uint256 shares = fleetCommander.balanceOf(address(this));
        if (shares == 0) {
            emit TipJarShaken(address(fleetCommander), 0);
            return;
        }

        uint256 withdrawnAssets = fleetCommander.redeem(
            Constants.MAX_UINT256,
            address(this),
            address(this)
        );

        if (withdrawnAssets == 0) {
            emit TipJarShaken(address(fleetCommander), 0);
            return;
        }

        IERC20 underlyingAsset = IERC20(fleetCommander.asset());

        // Distribute assets to tip stream recipients
        uint256 totalDistributed = 0;
        Percentage totalAllocated = toPercentage(0);
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            address recipient = tipStreamRecipients[i];
            Percentage allocation = tipStreams[recipient].allocation;
            totalAllocated = totalAllocated + allocation;

            uint256 amount;
            // Handle the last recipient differently to account for rounding errors
            if (totalAllocated == PERCENTAGE_100) {
                amount = withdrawnAssets - totalDistributed;
            } else {
                amount = withdrawnAssets.applyPercentage(allocation);
            }

            if (amount > 0) {
                underlyingAsset.safeTransfer(recipient, amount);
                totalDistributed += amount;
            }
        }

        // Transfer remaining balance to treasury
        uint256 remaining = withdrawnAssets - totalDistributed;
        if (remaining > 0) {
            underlyingAsset.safeTransfer(treasury(), remaining);
        }

        emit TipJarShaken(address(fleetCommander), withdrawnAssets);
    }

    /**
     * @notice Shakes multiple fleet commanders
     * @param fleetCommanders An array of fleet commander addresses to shake
     * @dev This function is used internally by shakeMultiple and shakeAll
     */
    function _shakeMultiple(address[] memory fleetCommanders) internal {
        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            _shake(fleetCommanders[i]);
        }
    }

    /**
     * @notice Validates that a tip stream exists and is not locked
     * @param recipient The address of the tip stream recipient
     * @custom:internal-logic
     * - Checks if the tip stream exists for the given recipient
     * - Verifies if the current time is past the locked until epoch
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Prevents operations on non-existent tip streams
     * - Enforces time-based locks on tip streams
     */
    function _validateTipStream(address recipient) internal view {
        if (tipStreams[recipient].recipient == address(0)) {
            revert TipStreamDoesNotExist(recipient);
        }
        if (block.timestamp < tipStreams[recipient].lockedUntilEpoch) {
            revert TipStreamLocked(recipient);
        }
    }

    /**
     * @notice Validates the allocation for a tip stream
     * @param newAllocation The allocation to validate
     * @param currentAllocation The current allocation to compare against
     * @custom:internal-logic
     * - Checks if the new allocation is valid (non-zero and within range)
     * - Verifies that the total allocation after the change doesn't exceed 100%
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Prevents invalid allocations (zero or out of range)
     * - Ensures the total allocation across all tip streams remains valid
     * - Accounts for the difference between new and current allocation when checking total
     */
    function _validateTipStreamAllocation(
        Percentage newAllocation,
        Percentage currentAllocation
    ) internal view {
        if (
            newAllocation == toPercentage(0) ||
            !PercentageUtils.isPercentageInRange(newAllocation)
        ) {
            revert InvalidTipStreamAllocation(newAllocation);
        }
        if (
            !PercentageUtils.isPercentageInRange(
                getTotalAllocation() + newAllocation - currentAllocation
            )
        ) {
            revert TotalAllocationExceedsOneHundredPercent();
        }
    }
}
