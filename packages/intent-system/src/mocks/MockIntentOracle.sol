// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IIntentOracle} from "../interfaces/IIntentOracle.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MockIntentOracle
 * @notice Mock oracle contract for testing the intent system
 * @dev Provides mock price data for testing purposes
 *
 * @dev DECIMAL CONVENTION:
 * - All prices are in USD with 18 decimal places
 * - For USDC (6 decimals) at $1.00: price = 1e18, decimals = 6
 * - For SUMR (18 decimals) at $1.00: price = 1e18, decimals = 18
 * - Notional calculation: (amount * price) / (10 ** decimals)
 */
contract MockIntentOracle is IIntentOracle, AccessControl {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant DEFAULT_PRICE = 1e18; // $1.00 USD with 18 decimal places
    uint256 public constant DEFAULT_DECIMALS = 18; // Default token decimals (Summer token)
    uint256 public constant MAX_PRICE_AGE = 1 hours;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address => PriceData) public prices;
    mapping(address => bool) public supportedTokens;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPrice(
        address token
    )
        external
        view
        override
        returns (uint256 price, uint256 timestamp, uint8 decimals)
    {
        if (!supportedTokens[token]) revert InvalidToken();

        PriceData memory priceData = prices[token];
        if (priceData.timestamp == 0) {
            // Return default price if not set
            return (DEFAULT_PRICE, block.timestamp, uint8(DEFAULT_DECIMALS));
        }

        return (priceData.price, priceData.timestamp, priceData.decimals);
    }

    function getPriceData(
        address token
    ) external view override returns (PriceData memory) {
        if (!supportedTokens[token]) revert InvalidToken();

        PriceData memory priceData = prices[token];
        if (priceData.timestamp == 0) {
            return
                PriceData({
                    price: DEFAULT_PRICE,
                    timestamp: block.timestamp,
                    decimals: uint8(DEFAULT_DECIMALS)
                });
        }

        return priceData;
    }

    function isPriceStale(
        address token,
        uint256 maxAge
    ) external view override returns (bool) {
        if (!supportedTokens[token]) revert InvalidToken();

        PriceData memory priceData = prices[token];
        if (priceData.timestamp == 0) return false; // Default price is never stale

        return (block.timestamp - priceData.timestamp) > maxAge;
    }

    function calculateNotionalValue(
        address token,
        uint256 amount
    ) external view override returns (uint256 notionalValue) {
        if (!supportedTokens[token]) revert InvalidToken();

        PriceData memory priceData = prices[token];
        uint256 price = priceData.timestamp == 0
            ? DEFAULT_PRICE
            : priceData.price;
        uint8 decimals = priceData.timestamp == 0
            ? uint8(DEFAULT_DECIMALS)
            : priceData.decimals;

        // Calculate notional value: amount * price / 10^tokenDecimals
        // This converts to USD with 18 decimal places
        notionalValue = (amount * price) / (10 ** decimals);
    }

    function getMaxPriceAge() external pure override returns (uint256) {
        return MAX_PRICE_AGE;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setPrice(
        address token,
        uint256 price,
        uint8 decimals
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedTokens[token] = true;
        prices[token] = PriceData({
            price: price,
            timestamp: block.timestamp,
            decimals: decimals
        });

        emit PriceUpdated(token, price, block.timestamp);
    }

    function addSupportedToken(
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedTokens[token] = true;
    }

    function removeSupportedToken(
        address token
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedTokens[token] = false;
        delete prices[token];
    }
}
