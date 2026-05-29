// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface ISuperstateStandardArkErrors {
    error InvalidDepositAddress();
    error InsufficientPendingDeposit();
    error PendingDepositActive();
    error ArkIsFrozen();
    error NotAllowlisted();
    error InsufficientYield();
}
