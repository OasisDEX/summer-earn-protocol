// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface ISuperstateStandardArkEvents {
    event PendingDepositCleared(uint256 amountCleared);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
}
