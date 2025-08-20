// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IIntentOracle
 * @notice Interface for the intent oracle contract that provides price feeds for the intent system
 *
 * @dev DECIMAL HANDLING CONVENTION:
 * - All prices are quoted in USD with 18 decimal places (e.g., 1 USD = 1e18, 0.5 USD = 5e17)
 * - The 'decimals' field in PriceData refers to the token's decimal places, NOT the price precision
 * - For price conversions: (tokenAmount * price) / (10 ** tokenDecimals)
 * - Example: For USDC (6 decimals) priced at $1.00:
 *   - price = 1e18 (1 USD with 18 decimal places)
 *   - decimals = 6 (USDC's decimal places)
 *   - To get USD value of 1000 USDC: (1000e6 * 1e18) / (10 ** 6) = 1000e18 = $1000.00
 *
 * @dev SUPPORTED TOKENS:
 * - Summer token (SUMR): 18 decimals, priced in USD
 * - USDC: 6 decimals, priced in USD
 * - Future tokens: Must follow ERC20 decimal conventions
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
        /// @notice Price in USD with 18 decimal places (e.g., 1e18 = $1.00)
        uint256 price;
        /// @notice Timestamp when the price was last updated
        uint256 timestamp;
        /// @notice Number of decimal places the token uses (e.g., 6 for USDC, 18 for most ERC20)
        uint8 decimals;
    }

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the latest price for a token
     * @param token Address of the token
     * @return price Current price in USD with 18 decimal places (e.g., 1e18 = $1.00)
     * @return timestamp Timestamp when the price was last updated
     * @return decimals Number of decimal places the token uses (e.g., 6 for USDC, 18 for SUMR)
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
     * @notice Calculates the notional value of a token amount in USD
     * @param token Address of the token
     * @param amount Amount of tokens (in token's native decimal representation)
     * @return notionalValue USD value with 18 decimal places (e.g., 1000e18 = $1000.00)
     * @dev Formula: (amount * price) / (10 ** tokenDecimals)
     * @dev Example: 1000 USDC (1000e6) at $1.00 = (1000e6 * 1e18) / (10 ** 6) = 1000e18 = $1000.00
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
