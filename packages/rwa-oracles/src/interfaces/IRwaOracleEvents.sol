// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRwaOracleEvents {
    event PriceUpdated(int256 price, uint256 timestamp, uint256 roundId);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event ThresholdUpdated(uint256 threshold);
}
