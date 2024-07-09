// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @notice Transfers disabled for legal reasons
error FleetCommanderTransfersDisabled();
error FleetCommanderArkNotFound(address ark);
error FleetCommanderCantRebalanceToArk(address ark);
error FleetCommanderTargetArkRateTooLow(
    address ark,
    uint256 targetRate,
    uint256 currentRate
);
error FleetCommanderRebalanceNoOperations();
error FleetCommanderRebalanceTooManyOperations(uint256 operationsCount);
error FleetCommanderRebalanceAmountZero(address ark);
error WithdrawalAmountIsBelowMinThreshold();
error WithdrawalAmountExceedsMaxBufferLimit();
error FleetCommanderArkAlreadyExists(address ark);
error FleetCommanderArkMaxAllocationZero(address ark);
error FleetCommanderInvalidArkAddress();
error FleetCommanderNoFundsMoved();
error FleetCommanderNoExcessFunds();
error FleetCommanderInvalidSourceArk(address ark);
error FleetCommanderMovedMoreThanAvailable();
