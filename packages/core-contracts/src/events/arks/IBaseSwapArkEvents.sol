// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

interface IBaseSwapArkEvents {
    event SlippageUpdated(Percentage newSlippagePercentage);
}
