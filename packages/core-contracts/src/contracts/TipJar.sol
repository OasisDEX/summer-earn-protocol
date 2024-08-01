// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ITipJar} from "../interfaces/ITipJar.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {PercentageUtils} from "../libraries/PercentageUtils.sol";
import "../errors/TipJarErrors.sol";
import {Percentage, fromPercentage, toPercentage} from "../types/Percentage.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

/**
 * @title TipJar
 * @notice Contract implementing the centralised collection of Tips
 */
contract TipJar is ITipJar, ProtocolAccessManaged {
    using PercentageUtils for uint256;

    mapping(address => TipStream) public tipStreams;
    address[] public tipStreamRecipients;
    address public treasuryAddress;

    constructor(
        address accessManager,
        address _treasuryAddress_
    ) ProtocolAccessManaged(accessManager) {
        treasuryAddress = _treasuryAddress_;
    }

    function addTipStream(
        address recipient,
        Percentage allocation,
        uint256 minimumTerm
    ) external onlyGovernor {
        _validateTipStreamAllocation(allocation);

        tipStreams[recipient] = TipStream({
            recipient: recipient,
            allocation: allocation,
            minimumTerm: minimumTerm
        });
        tipStreamRecipients.push(recipient);

        emit TipStreamAdded(recipient, allocation, minimumTerm);
    }

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

    function updateTipStream(
        address recipient,
        Percentage newAllocation,
        uint256 newMinimumTerm
    ) external onlyGovernor {
        _validateTipStream(recipient);
        _validateTipStreamAllocation(newAllocation);

        tipStreams[recipient].allocation = newAllocation;
        tipStreams[recipient].minimumTerm = newMinimumTerm;

        emit TipStreamUpdated(recipient, newAllocation, newMinimumTerm);
    }

    function getTipStream(
        address recipient
    ) external view returns (TipStream memory) {
        return tipStreams[recipient];
    }

    function getAllTipStreams() external view returns (TipStream[] memory) {
        TipStream[] memory allStreams = new TipStream[](
            tipStreamRecipients.length
        );
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            allStreams[i] = tipStreams[tipStreamRecipients[i]];
        }
        return allStreams;
    }

    function shake(IFleetCommander fleetCommander) public {
        uint256 shares = fleetCommander.balanceOf(address(this));
        if (shares == 0) {
            revert NoSharesToDistribute();
        }

        uint256 assets = fleetCommander.redeem(
            shares,
            address(this),
            address(this)
        );
        IERC20 underlyingAsset = IERC20(fleetCommander.asset());

        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            address recipient = tipStreamRecipients[i];
            Percentage allocation = tipStreams[recipient].allocation;
            uint256 amount = assets.applyPercentage(allocation);

            if (amount > 0) {
                underlyingAsset.transfer(recipient, amount);
                totalDistributed += amount;
            }
        }

        // Transfer remaining balance to treasury
        uint256 remaining = assets - totalDistributed;
        if (remaining > 0) {
            underlyingAsset.transfer(treasuryAddress, remaining);
        }

        emit TipJarShaken(address(fleetCommander), assets);
    }

    function shakeMultiple(
        IFleetCommander[] calldata fleetCommanders
    ) external {
        for (uint256 i = 0; i < fleetCommanders.length; i++) {
            shake(fleetCommanders[i]);
        }
    }

    function getTotalAllocation() public view returns (Percentage) {
        Percentage total = toPercentage(0);
        for (uint256 i = 0; i < tipStreamRecipients.length; i++) {
            total = total + tipStreams[tipStreamRecipients[i]].allocation;
        }
        return total;
    }

    function setTreasuryAddress(
        address newTreasuryAddress
    ) external onlyGovernor {
        if (newTreasuryAddress == address(0)) {
            revert InvalidTreasuryAddress();
        }
        treasuryAddress = newTreasuryAddress;
    }

    function _validateTipStream(address recipient) internal view {
        if (tipStreams[recipient].recipient == address(0)) {
            revert TipStreamDoesNotExist(recipient);
        }
        if (block.timestamp < tipStreams[recipient].minimumTerm) {
            revert TipStreamMinTermNotReached(recipient);
        }
    }

    function _validateTipStreamAllocation(Percentage allocation) internal view {
        if (
            allocation == toPercentage(0) ||
            !PercentageUtils.isPercentageInRange(allocation)
        ) {
            revert InvalidTipStreamAllocation(allocation);
        }
        if (
            !PercentageUtils.isPercentageInRange(
                getTotalAllocation() + allocation
            )
        ) {
            revert TotalAllocationExceedsOneHundredPercent();
        }
    }
}
