// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateStandardArkEvents {
    event RedemptionExecuted(uint256 shareAmount, uint256 expectedUsdc);
    event PendingDepositCleared(uint256 amountCleared);
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );
}
