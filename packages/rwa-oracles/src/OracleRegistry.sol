// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOracleRegistry} from "./interfaces/IOracleRegistry.sol";

contract OracleRegistry is Ownable, IOracleRegistry {
    mapping(string => address) public tickerToOracle;
    mapping(address => address) public assetToOracle;

    // Reverse mappings for discovery
    mapping(address => string) public oracleToTicker;
    mapping(address => address) public oracleToAsset;

    constructor(address _owner) Ownable(_owner) {}

    function setOracle(
        string calldata ticker,
        address asset,
        address oracle
    ) external onlyOwner {
        if (bytes(ticker).length == 0) revert InvalidTicker();
        if (asset == address(0)) revert InvalidAsset();
        if (oracle == address(0)) revert InvalidOracle();

        tickerToOracle[ticker] = oracle;
        assetToOracle[asset] = oracle;

        oracleToTicker[oracle] = ticker;
        oracleToAsset[oracle] = asset;

        emit OracleSet(ticker, asset, oracle);
    }

    function getOracleByTicker(
        string calldata ticker
    ) external view returns (address) {
        return tickerToOracle[ticker];
    }

    function getOracleByAsset(address asset) external view returns (address) {
        return assetToOracle[asset];
    }
}
