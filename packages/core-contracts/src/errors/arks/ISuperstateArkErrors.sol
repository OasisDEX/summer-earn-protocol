// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISuperstateArkErrors {
    error InvalidShareTokenAddress();
    error InvalidOracleAddress();
    error InvalidRedeemAddress();
    error OraclePriceNotPositive();
    error StaleOraclePrice();
    error OnlySelf();
    error InvalidSweepSlippage(Percentage newSlippage, Percentage maxSlippage);
    error InsufficientAssetsReturned(
        uint256 receivedAssets,
        uint256 expectedShares,
        uint256 receivedShares
    );
}
