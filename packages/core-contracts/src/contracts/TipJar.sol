// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ITipJar} from "../interfaces/ITipJar.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title TipJar
 * @notice Contract implementing the centralised collection of Tips
 */
contract TipJar is ITipJar, ProtocolAccessManaged {
    mapping(address => TipStream) public tipStreams;
    address[] public tipStreamRecipients;
    uint256 public constant BASE = 10000;
    address public treasuryAddress;

    constructor(address _accessManager, address _treasuryAddress) ProtocolAccessManaged(_accessManager) {
        treasuryAddress = _treasuryAddress;
    }

    function addTipStream(address recipient, uint256 allocation, uint256 minimumTerm) external onlyGovernor {
        require(recipient != address(0), "Invalid recipient address");
        require(tipStreams[recipient].recipient == address(0), "TipStream already exists");
        require(allocation > 0 && allocation <= BASE, "Invalid allocation");
        require(getTotalAllocation() + allocation <= BASE, "Total allocation exceeds 100%");

        tipStreams[recipient] = TipStream({
            recipient: recipient,
            allocation: allocation,
            minimumTerm: minimumTerm
        });
        tipStreamRecipients.push(recipient);

        emit TipStreamAdded(recipient, allocation, minimumTerm);
    }

    function removeTipStream(address recipient) external onlyGovernor {
        require(tipStreams[recipient].recipient != address(0), "TipStream does not exist");
        require(block.timestamp >= tipStreams[recipient].minimumTerm, "Minimum term not reached");

        delete tipStreams[recipient];
        for (uint i = 0; i < tipStreamRecipients.length; i++) {
            if (tipStreamRecipients[i] == recipient) {
                tipStreamRecipients[i] = tipStreamRecipients[tipStreamRecipients.length - 1];
                tipStreamRecipients.pop();
                break;
            }
        }

        emit TipStreamRemoved(recipient);
    }

    function updateTipStream(address recipient, uint256 newAllocation, uint256 newMinimumTerm) external onlyGovernor {
        require(tipStreams[recipient].recipient != address(0), "TipStream does not exist");
        require(block.timestamp >= tipStreams[recipient].minimumTerm, "Minimum term not reached");
        require(newAllocation > 0 && newAllocation <= BASE, "Invalid allocation");

        uint256 totalAllocation = getTotalAllocation() - tipStreams[recipient].allocation + newAllocation;
        require(totalAllocation <= BASE, "Total allocation exceeds 100%");

        tipStreams[recipient].allocation = newAllocation;
        tipStreams[recipient].minimumTerm = newMinimumTerm;

        emit TipStreamUpdated(recipient, newAllocation, newMinimumTerm);
    }

    function getTipStream(address recipient) external view returns (TipStream memory) {
        return tipStreams[recipient];
    }

    function getAllTipStreams() external view returns (TipStream[] memory) {
        TipStream[] memory allStreams = new TipStream[](tipStreamRecipients.length);
        for (uint i = 0; i < tipStreamRecipients.length; i++) {
            allStreams[i] = tipStreams[tipStreamRecipients[i]];
        }
        return allStreams;
    }

    function shake(IERC4626 fleetCommander) external {
        uint256 shares = fleetCommander.balanceOf(address(this));
        require(shares > 0, "No shares to distribute");

        uint256 assets = fleetCommander.redeem(shares, address(this), address(this));
        IERC20 underlyingAsset = IERC20(fleetCommander.asset());

        uint256 totalDistributed = 0;
        for (uint i = 0; i < tipStreamRecipients.length; i++) {
            address recipient = tipStreamRecipients[i];
            uint256 allocation = tipStreams[recipient].allocation;
            uint256 amount = (assets * allocation) / BASE;

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

    function shakeMultiple(IERC4626[] calldata fleetCommanders) external {
        for (uint i = 0; i < fleetCommanders.length; i++) {
            shake(fleetCommanders[i]);
        }
    }

    function getTotalAllocation() public view returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < tipStreamRecipients.length; i++) {
            total += tipStreams[tipStreamRecipients[i]].allocation;
        }
        return total;
    }

    function setTreasuryAddress(address newTreasuryAddress) external onlyGovernor {
        require(newTreasuryAddress != address(0), "Invalid treasury address");
        treasuryAddress = newTreasuryAddress;
    }
}