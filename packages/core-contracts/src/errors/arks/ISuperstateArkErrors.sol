// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

interface ISuperstateArkErrors {
    error InvalidShareTokenAddress();
    error InvalidOracleAddress();
    error InvalidRedeemAddress();
    error OraclePriceNotPositive();
    error StaleOraclePrice();
}
