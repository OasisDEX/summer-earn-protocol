// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOracleRegistry} from "./interfaces/IOracleRegistry.sol";

/**
 * @title OracleRegistry
 * @author Summer
 * @notice Central registry mapping ticker symbols and asset addresses to their corresponding RWA oracles.
 * @dev Enables discovery of oracles by ticker (e.g. "SPXUX") or by asset token address.
 *      The owner manages all mappings. Supports reverse lookups for integration with consumers.
 */
contract OracleRegistry is Ownable, IOracleRegistry {
    /// @notice Ticker symbol => oracle address
    mapping(string => address) public tickerToOracle;
    /// @notice Asset token address => oracle address
    mapping(address => address) public assetToOracle;

    /// @notice Oracle address => ticker symbol (reverse lookup)
    mapping(address => string) public oracleToTicker;
    /// @notice Oracle address => asset token address (reverse lookup)
    mapping(address => address) public oracleToAsset;

    /// @param _owner Address that will own the registry and manage oracle mappings
    constructor(address _owner) Ownable(_owner) {}

    /**
     * @notice Register or update an oracle for a given ticker and asset.
     * @param ticker Ticker symbol (e.g. "SPXUX"). Must be non-empty.
     * @param asset Address of the underlying asset token this oracle prices.
     * @param oracle Address of the RwaOracle contract providing price feed.
     * @dev Reverts with InvalidTicker, InvalidAsset, or InvalidOracle if any input is invalid.
     *      Overwrites any existing mapping for the same ticker or asset.
     */
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

    /**
     * @notice Get the oracle address for a ticker symbol.
     * @param ticker Ticker symbol to look up.
     * @return Address of the oracle, or zero address if not registered.
     */
    function getOracleByTicker(
        string calldata ticker
    ) external view returns (address) {
        return tickerToOracle[ticker];
    }

    /**
     * @notice Get the oracle address for an asset token.
     * @param asset Address of the asset token to look up.
     * @return Address of the oracle, or zero address if not registered.
     */
    function getOracleByAsset(address asset) external view returns (address) {
        return assetToOracle[asset];
    }
}
