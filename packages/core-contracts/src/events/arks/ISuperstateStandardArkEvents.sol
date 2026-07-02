// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title ISuperstateStandardArkEvents
 * @notice Events emitted by the Superstate standard Ark contract
 */
interface ISuperstateStandardArkEvents {
    /**
     * @notice Emitted when a pending deposit is cleared
     * @param amountCleared The amount of the pending deposit that was cleared
     */
    event PendingDepositCleared(uint256 amountCleared);
    /**
     * @notice Emitted when the Ark frozen state is updated
     * @param isFrozen Whether the Ark is now frozen
     * @param frozenTotalAssets The total assets recorded at the time of freezing
     */
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
}
