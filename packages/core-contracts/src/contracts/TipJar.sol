// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {ITipJar} from "../interfaces/ITipJar.sol";

import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {PERCENTAGE_100, Percentage, fromPercentage, toPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title TipJar
 * @notice Contract implementing the centralized collection and distribution of tips
 * @dev This contract manages tip streams, allowing for the addition, removal, and updating of tip allocations
 */
contract TipJar is ITipJar, ProtocolAccessManaged {
    using PercentageUtils for uint256;

    mapping(address recipient => TipStream tipStream) public tipStreams;
    address[] public tipStreamRecipients;
    IConfigurationManager public manager;

    /**
     * @notice Constructs a new TipJar contract
     * @param _accessManager The address of the access manager contract
     * @param _configurationManager The address of the configuration manager contract
     */
    constructor(
        address _accessManager,
        address _configurationManager
    ) ProtocolAccessManaged(_accessManager) {
        manager = IConfigurationManager(_configurationManager);
    }

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
     */
    function _shake(address fleetCommander_) internal {
        if (fleetCommander_ == address(0)) {
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
            underlyingAsset.transfer(manager.treasury(), remaining);
        }

        emit TipJarShaken(address(fleetCommander), withdrawnAssets);
    }

    /**
     * @notice Validates that a tip stream exists and is not locked
     * @param recipient The address of the tip stream recipient
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
