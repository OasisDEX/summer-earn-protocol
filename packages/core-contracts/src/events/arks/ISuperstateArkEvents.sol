// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateArkEvents {
    event SubscriptionExecuted(uint256 usdcAmount, address target);
    event RedemptionExecuted(uint256 shareAmount, uint256 expectedUsdc);
    event SweepSlippageUpdated(
        Percentage oldSweepSlippage,
        Percentage newSweepSlippage
    );
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );
}
