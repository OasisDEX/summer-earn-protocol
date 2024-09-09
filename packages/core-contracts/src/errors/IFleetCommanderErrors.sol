// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
interface IFleetCommanderErrors {
    /// @notice Transfers disabled for legal reasons
    error FleetCommanderTransfersDisabled();
    error FleetCommanderArkNotFound(address ark);
    error FleetCommanderArkNotActive(address ark);
    error FleetCommanderCantRebalanceToArk(address ark);
    error FleetCommanderInvalidBufferAdjustment();
    error FleetCommanderInsufficientBuffer();
    error FleetCommanderRebalanceNoOperations();
    error FleetCommanderRebalanceTooManyOperations(uint256 operationsCount);
    error FleetCommanderRebalanceAmountZero(address ark);
    error WithdrawalAmountIsBelowMinThreshold();
    error WithdrawalAmountExceedsMaxBufferLimit();
    error FleetCommanderArkAlreadyExists(address ark);
    error FleetCommanderArkDepositCapZero(address ark);
    error FleetCommanderInvalidArkAddress();
    error FleetCommanderNoFundsMoved();
    error FleetCommanderNoExcessFunds();
    error FleetCommanderInvalidSourceArk(address ark);
    error FleetCommanderMovedMoreThanAvailable();
    error FleetCommanderArkDepositCapGreaterThanZero(address ark);
    error FleetCommanderArkAssetsNotZero(address ark);
    error FleetCommanderUnauthorizedWithdrawal(address caller, address owner);
    error FleetCommanderUnauthorizedRedemption(address caller, address owner);
    error FleetCommanderCantUseRebalanceOnBufferArk();
    error FleetCommanderCantUseMaxUintForBufferAdjustement();
    error FleetCommanderExceedsMaxOutflow(
        address fromArk,
        uint256 amount,
        uint256 maxRebalanceOutflow
    );
    error FleetCommanderExceedsMaxInflow(
        address fromArk,
        uint256 amount,
        uint256 maxRebalanceInflow
    );
}
