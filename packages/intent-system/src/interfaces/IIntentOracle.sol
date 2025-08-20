// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IIntentOracle
 * @notice Interface for the intent oracle contract that provides price verification for Summer tokens
 */
interface IIntentOracle {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error StalePrice();
    error InvalidToken();
    error PriceTooOld();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint8 decimals;
    }

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the latest price for a token
     * @param token Address of the token
     * @return price Current price of the token
     * @return timestamp Timestamp when the price was last updated
     * @return decimals Number of decimals for the price
     */
    function getPrice(
        address token
    ) external view returns (uint256 price, uint256 timestamp, uint8 decimals);

    /**
     * @notice Gets the price data for a token
     * @param token Address of the token
     * @return PriceData struct containing price information
     */
    function getPriceData(
        address token
    ) external view returns (PriceData memory);

    /**
     * @notice Checks if a price is stale
     * @param token Address of the token
     * @param maxAge Maximum age in seconds for the price to be considered fresh
     * @return True if price is stale, false otherwise
     */
    function isPriceStale(
        address token,
        uint256 maxAge
    ) external view returns (bool);

    /**
     * @notice Calculates the notional value of a token amount
     * @param token Address of the token
     * @param amount Amount of tokens
     * @return notionalValue Notional value in USD (or base currency)
     */
    function calculateNotionalValue(
        address token,
        uint256 amount
    ) external view returns (uint256 notionalValue);

    /**
     * @notice Gets the maximum age for prices to be considered fresh
     * @return Maximum age in seconds
     */
    function getMaxPriceAge() external view returns (uint256);
}
