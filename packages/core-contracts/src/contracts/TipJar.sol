// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ITipJar} from "../interfaces/ITipJar.sol";

import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ConfigurationManaged} from "./ConfigurationManaged.sol";
import {PERCENTAGE_100, Percentage, fromPercentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";

/**
 * @custom:see ITipJar
 */
contract TipJar is ITipJar, ProtocolAccessManaged, ConfigurationManaged {
    using PercentageUtils for uint256;

    mapping(address recipient => TipStream tipStream) public tipStreams;
    address[] public tipStreamRecipients;

    /**
     * @notice Constructs a new TipJar contract
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

    /// @inheritdoc ITipJar
    function addTipStream(
        TipStream memory tipStream
    ) external onlyGovernor returns (uint256 lockedUntilEpoch) {
        if (tipStreams[tipStream.recipient].recipient != address(0)) {
            revert TipStreamAlreadyExists(tipStream.recipient);
        }
        _validateTipStreamAllocation(
            tipStream.allocation,
            tipStreams[tipStream.recipient].allocation
        );

        tipStreams[tipStream.recipient] = tipStream;
        tipStreamRecipients.push(tipStream.recipient);

        emit TipStreamAdded(tipStream);
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

    /// @inheritdoc ITipJar
    function updateTipStream(TipStream memory tipStream) external onlyGovernor {
        _validateTipStream(tipStream.recipient);
        TipStream memory oldTipStream = tipStreams[tipStream.recipient];
        Percentage currentAllocation = oldTipStream.allocation;
        _validateTipStreamAllocation(tipStream.allocation, currentAllocation);

        tipStreams[tipStream.recipient].allocation = tipStream.allocation;
        tipStreams[tipStream.recipient].lockedUntilEpoch = tipStream
            .lockedUntilEpoch;

        emit TipStreamUpdated(oldTipStream, tipStream);
    }

    /// @inheritdoc ITipJar
    function getTipStream(
        address recipient
    ) external view returns (TipStream memory) {
        return tipStreams[recipient];
    }

    /// @inheritdoc ITipJar
    function getAllTipStreams() external view returns (TipStream[] memory) {
        TipStream[] memory allStreams = new TipStream[](
            tipStreamRecipients.length
        );
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            allStreams[i] = tipStreams[tipStreamRecipients[i]];
        }
        return allStreams;
    }

    /// @inheritdoc ITipJar
    function shake(address fleetCommander_) public {
        _shake(fleetCommander_);
    }

    /// @inheritdoc ITipJar
    function shakeMultiple(address[] calldata fleetCommanders) external {
        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            _shake(fleetCommanders[i]);
        }
    }

    /// @inheritdoc ITipJar
    function getTotalAllocation() public view returns (Percentage total) {
        total = toPercentage(0);
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            total = total + tipStreams[tipStreamRecipients[i]].allocation;
        }
    }

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
            revert NoSharesToRedeem();
        }

        uint256 withdrawnAssets = fleetCommander.redeem(
            shares,
            address(this),
            address(this)
        );

        if (withdrawnAssets == 0) {
            revert NoAssetsToDistribute();
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
                underlyingAsset.transfer(recipient, amount);
                totalDistributed += amount;
            }
        }

        // Transfer remaining balance to treasury
        uint256 remaining = withdrawnAssets - totalDistributed;
        if (remaining > 0) {
            underlyingAsset.transfer(treasury(), remaining);
        }

        emit TipJarShaken(address(fleetCommander), withdrawnAssets);
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
