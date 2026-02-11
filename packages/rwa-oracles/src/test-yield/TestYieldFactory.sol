// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TestYieldToken} from "./TestYieldToken.sol";

/**
 * @title TestYieldFactory
 * @author Summer
 * @notice Factory for deploying and managing TestYieldToken contracts per ticker.
 * @dev Owner is the deployer. Factory owns all deployed tokens and can process deposits/withdrawals.
 */
contract TestYieldFactory is Ownable {
    event YieldTokenDeployed(string ticker, address token, address pocket);

    /// @notice Ticker symbol => TestYieldToken address
    mapping(string => address) public tickers;
    /// @notice Array of all deployed token addresses
    address[] public allTickers;
    /// @notice Token address => ticker (reverse lookup)
    mapping(address => string) public addressToTicker;

    /// @param _owner Owner address (deployer)
    constructor(address _owner) Ownable(_owner) {}

    /**
     * @notice Deploy a new TestYieldToken for a ticker.
     * @param name ERC20 name (e.g. "Test Yield SPXUX")
     * @param ticker Ticker symbol (e.g. "SPXUX")
     * @param usdc USDC token address
     * @param oracle Price oracle address
     * @return Address of the deployed TestYieldToken
     * @dev Reverts if ticker already exists. Factory becomes owner of the token.
     */
    function deployYieldToken(
        string memory name,
        string memory ticker,
        address usdc,
        address oracle
    ) external onlyOwner returns (address) {
        require(tickers[ticker] == address(0), "Ticker already exists");

        TestYieldToken token = new TestYieldToken(
            name,
            ticker,
            usdc,
            oracle,
            address(this)
        ); // Factory is owner
        tickers[ticker] = address(token);
        allTickers.push(address(token));
        addressToTicker[address(token)] = ticker;

        emit YieldTokenDeployed(ticker, address(token), token.getPocket());
        return address(token);
    }

    /**
     * @notice Get all deployed token addresses.
     * @return Array of TestYieldToken addresses.
     */
    function getAllTickers() external view returns (address[] memory) {
        return allTickers;
    }

    /**
     * @notice Process a deposit for a ticker. Forwards to the token's processDeposit.
     * @param ticker Ticker symbol
     * @param user Address to receive shares
     * @param usdcAmount USDC amount (6 decimals)
     */
    function processDeposit(
        string memory ticker,
        address user,
        uint256 usdcAmount
    ) external onlyOwner {
        address token = tickers[ticker];
        require(token != address(0), "Ticker not found");
        TestYieldToken(token).processDeposit(user, usdcAmount);
    }

    /**
     * @notice Process a withdrawal for a ticker. Forwards to the token's processWithdraw.
     * @param ticker Ticker symbol
     * @param user Address to receive USDC
     * @param sharesAmount Share amount (18 decimals)
     */
    function processWithdraw(
        string memory ticker,
        address user,
        uint256 sharesAmount
    ) external onlyOwner {
        address token = tickers[ticker];
        require(token != address(0), "Ticker not found");
        TestYieldToken(token).processWithdraw(user, sharesAmount);
    }

    /**
     * @notice Process multiple deposits in one transaction.
     * @param _tickers Array of ticker symbols
     * @param users Array of user addresses (receivers)
     * @param amounts Array of USDC amounts (6 decimals)
     * @dev All arrays must have the same length.
     */
    function batchProcessDeposits(
        string[] memory _tickers,
        address[] memory users,
        uint256[] memory amounts
    ) external onlyOwner {
        require(
            _tickers.length == users.length && users.length == amounts.length,
            "Length mismatch"
        );
        for (uint256 i = 0; i < _tickers.length; i++) {
            address token = tickers[_tickers[i]];
            require(token != address(0), "Ticker not found");
            TestYieldToken(token).processDeposit(users[i], amounts[i]);
        }
    }

    /**
     * @notice Get the token address for a ticker.
     * @param ticker Ticker symbol
     * @return Token address, or zero if not deployed
     */
    function getTickerAddress(
        string memory ticker
    ) external view returns (address) {
        return tickers[ticker];
    }
}
