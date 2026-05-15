// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateStandardArkErrors {
    error InvalidDepositAddress();
    error InsufficientPendingDeposit();
    error PendingDepositActive();
    error ArkIsFrozen();
    error InvalidDepositSlippage(
        Percentage newSlippage,
        Percentage maxSlippage
    );
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
    error SharesNotArrived(uint256 expectedShares, uint256 actualNewShares);
    error NotAllowlisted();
    error InsufficientYield();
}
