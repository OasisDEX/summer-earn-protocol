// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

interface IBaseSwapArkErrors {
    error OracleNotReady();
    error InvalidAssetForSY();
    error InvalidNextMarket();
    error OracleDurationTooLow(
        uint32 providedDuration,
        uint256 minimumDuration
    );
    error SlippagePercentageTooHigh(
        Percentage providedSlippage,
        Percentage maxSlippage
    );
    error MarketExpired();
    error InvalidArkTokenAddress();
    error SwapDataRequired();
    error SwapFailed();
    error InsufficientOutputAmount();
}
