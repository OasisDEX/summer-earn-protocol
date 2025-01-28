// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ICurveSwap {
    function last_price(uint256 i) external view returns (uint256);
    /**
     * @notice Returns the stored EMA (Exponential Moving Average) price without recalculation
     * @dev This returns the last stored EMA value which might be stale
     *      Cheaper gas cost but may not reflect current market conditions if not recently updated
     * @param i The index of the token
     * @return The stored EMA price value
     */
    function ema_price(uint256 i) external view returns (uint256);

    /**
     * @notice Returns the current oracle price, calculating new EMA if time has passed
     * @dev More expensive than ema_price() but provides most up-to-date value
     *      Calculates new EMA if time has passed since last update
     *      Should be used when current price accuracy is important
     * @param i The index of the token
     * @return The current oracle price
     */
    function price_oracle(uint256 i) external view returns (uint256);
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
    function coins(uint256 i) external view returns (address);
}
