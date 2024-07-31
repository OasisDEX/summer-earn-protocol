// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

error InvalidRecipientAddress();
error TipStreamAlreadyExists(address recipient);
error InvalidTipStreamAllocation(uint256 invalidAllocation);
error TotalAllocationExceedsOneHundredPercent();
error TipStreamDoesNotExist(address recipient);
error TipStreamMinTermNotReached(address recipient);