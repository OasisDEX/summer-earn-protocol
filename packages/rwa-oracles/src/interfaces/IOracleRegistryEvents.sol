// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracleRegistryEvents {
    event OracleSet(
        string indexed ticker,
        address indexed asset,
        address indexed oracle
    );
}
