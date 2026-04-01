// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StorageSlot} from "@summerfi/dependencies/openzeppelin-next/StorageSlot.sol";

import {IArk} from "../interfaces/IArk.sol";
import {ArkData} from "../types/FleetCommanderTypes.sol";
import {StorageSlots} from "./libraries/StorageSlots.sol";
import {FleetCommanderCacheLib} from "./libraries/FleetCommanderCacheLib.sol";

/**
 * @title FleetCommanderCache - Caching System
 * @dev This contract implements a caching mechanism
 *      for efficient asset tracking and operations.
 *
 * Caching System:
 * 1. Purpose: The caching system is designed to optimize gas costs and improve performance
 *    for operations that require frequent access to total assets and ark data.
 *
 * 2. Key Components:
 *    - FleetCommanderCache: A contract that this FleetCommander inherits from, providing
 *      caching functionality.
 *    - Cache Modifiers: 'useDepositCache' and 'useWithdrawCache' are used to manage the
 *      caching lifecycle for deposit and withdrawal operations.
 *
 * 3. Caching Mechanism:
 *    - Before Operation: The cache is populated with current ark data.
 *    - During Operation: The contract uses cached data instead of making repeated calls to arks.
 *    - After Operation: The cache is flushed to ensure data freshness for subsequent operations.
 *
 * 4. Benefits:
 *    - Gas Optimization: Reduces the number of external calls to arks, saving gas.
 *    - Consistency: Ensures that a single operation uses consistent data throughout its execution.
 *
 * 5. Cache Usage:
 *    - Deposit Operations: Uses 'useDepositCache' modifier to cache all ark data.
 *    - Withdrawal Operations: Uses 'useWithdrawCache' modifier to cache data for withdrawable arks.
 *    - Rebalance Operations: Does not use cache as it directly interacts with arks.
 *
 * 6. Cache Management:
 *    - Cache population: Performed by '_getArksData' and '_getWithdrawableArksData' functions.
 *    - Cache flushing: Done by '_flushCache' function after each operation.
 *
 * This caching system is crucial for maintaining efficient operations in the FleetCommander,
 * especially when dealing with multiple arks and frequent asset calculations.
 */
contract FleetCommanderCache {
    using StorageSlot for *;

    /**
     * @dev Checks if the FleetCommander is currently performing a trnsaction that includes a tip
     * @return bool True if collecting tips, false otherwise
     */
    function _isCollectingTip() internal view returns (bool) {
        return FleetCommanderCacheLib.isCollectingTip();
    }

    /**
     * @dev Sets the isCollectingTip flag
     * @param value The value to set the flag to
     */
    function _setIsCollectingTip(bool value) internal {
        FleetCommanderCacheLib.setIsCollectingTip(value);
    }

    /**
     * @dev Calculates the total assets across all arks
     * @param bufferArk The buffer ark instance
     * @return total The sum of total assets across all arks
     */
    function _totalAssets(
        IArk bufferArk
    ) internal view returns (uint256 total) {
        return
            FleetCommanderCacheLib.totalAssets(
                bufferArk,
                _getActiveArksAddresses()
            );
    }

    /**
     * @dev Calculates the total assets of withdrawable arks
     * @param bufferArk The buffer ark instance
     * @return withdrawableTotalAssets The sum of total assets across withdrawable arks
     *  - arks that don't require additional data to be boarded or disembarked from.
     * @custom:internal-logic
     * - Checks if withdrawable total assets are cached
     * - If cached, returns the cached value
     * - If not cached, calculates the sum of total assets across withdrawable arks
     * @custom:effects
     * - No state changes
     * @custom:security-considerations
     * - Relies on accurate reporting of total assets by individual arks
     * - Depends on the correctness of the withdrawableTotalAssets function
     */
    function _withdrawableTotalAssets(
        IArk bufferArk
    ) internal view returns (uint256 withdrawableTotalAssets) {
        return
            FleetCommanderCacheLib.withdrawableTotalAssets(
                bufferArk,
                _getActiveArksAddresses()
            );
    }

    /**
     * @dev Flushes the cache for all arks and related data
     * @custom:internal-logic
     * - Resets the cached data for all arks and related data
     * @custom:effects
     * - Sets IS_TOTAL_ASSETS_CACHED_STORAGE to false
     * - Sets IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE to false
     * - Resets WITHDRAWABLE_ARKS_LENGTH_STORAGE to 0
     * - Resets ARKS_LENGTH_STORAGE to 0
     * @custom:security-considerations
     * - Ensures that the next call to totalAssets or withdrawableTotalAssets recalculates values
     * - Critical for maintaining data freshness and preventing stale cache issues
     * - Flushes cache in case of reentrancy
     * - That also allows efficient testing using Forge (transient storage is persistent during single test)
     */
    function _flushCache() internal {
        FleetCommanderCacheLib.flushCache();
    }

    /**
     * @dev Retrieves the data (address, totalAssets) for all arks and the buffer ark
     * @param bufferArk The buffer ark instance
     * @return _arksData An array of ArkData structs containing the ark addresses and their total assets
     * @custom:internal-logic
     * - Initializes data for all arks including the buffer ark
     * - Populates data for regular arks and buffer ark
     * - Caches the total assets and ark data
     * - buffer ark is always at the end of the array
     * @custom:effects
     * - Caches total assets and ark data
     * - Modifies storage slots related to ark data
     * @custom:security-considerations
     * - Relies on accurate reporting of total assets by individual arks
     */
    function _getArksData(
        IArk bufferArk
    ) internal returns (ArkData[] memory _arksData) {
        return
            FleetCommanderCacheLib.getArksData(
                bufferArk,
                _getActiveArksAddresses()
            );
    }

    /**
     * @dev Caches the inflow and outflow balances for the specified Ark addresses.
     *      Updates the maximum inflow and outflow balances if they are not set.
     * @param outflowArkAddress The address of the Ark from which the outflow is occurring.
     * @param inflowArkAddress The address of the Ark to which the inflow is occurring.
     * @param amount The amount to be added to both inflow and outflow balances.
     * @return newInflowBalance The updated inflow balance for the inflow Ark.
     * @return newOutflowBalance The updated outflow balance for the outflow Ark.
     * @return maxInflow The maximum inflow balance for the inflow Ark.
     * @return maxOutflow The maximum outflow balance for the outflow Ark.
     */
    function _cacheArkFlow(
        address outflowArkAddress,
        address inflowArkAddress,
        uint256 amount
    )
        internal
        returns (
            uint256 newInflowBalance,
            uint256 newOutflowBalance,
            uint256 maxInflow,
            uint256 maxOutflow
        )
    {
        return
            FleetCommanderCacheLib.cacheArkFlow(
                outflowArkAddress,
                inflowArkAddress,
                amount
            );
    }

    /**
     * @notice Retrieves the data (address, totalAssets) for all withdrawable arks from cache
     * @return arksData An array of ArkData structs containing the ark addresses and their total assets
     */
    function _getWithdrawableArksDataFromCache()
        internal
        view
        returns (ArkData[] memory arksData)
    {
        return FleetCommanderCacheLib.getWithdrawableArksDataFromCache();
    }

    /**
     * @dev Retrieves and processes data for withdrawable arks
     * @param bufferArk The buffer ark instance
     * @custom:internal-logic
     * - Fetches data for all arks using _getArksData
     * - Filters arks based on withdrawability
     * - Accumulates total assets of withdrawable arks
     * - Resizes the array to remove empty slots
     * - Sorts the withdrawable arks by total assets
     * - Caches the processed data
     * - checks if the arks are cached, if yes skips the rest of the function
     * - cache check is important for nested calls e.g. withdraw (withdrawFromArks)
     * @custom:effects
     * - Modifies storage by caching withdrawable arks data
     * - Updates the total assets of withdrawable arks in storage
     * @custom:security-considerations
     * - Assumes the withdrawableTotalAssets function is correctly implemented by Ark contracts
     * - Uses assembly for array resizing, which bypasses Solidity's safety checks
     * - Relies on the correctness of '_getArksData' and 'FleetCommanderCacheLib.getWithdrawableArksData' functions
     */
    function _getWithdrawableArksData(IArk bufferArk) internal {
        FleetCommanderCacheLib.getWithdrawableArksData(
            bufferArk,
            _getActiveArksAddresses()
        );
    }

    /**
     * @notice Returns an array of addresses for all currently active Arks in the fleet
     * @dev This is an abstract internal function that must be implemented by the FleetCommander contract
     *      It serves as a critical component in the caching system for efficient ark management
     *
     * @return address[] An array containing the addresses of all active Arks
     *
     * @custom:purpose
     * - Provides the foundation for the caching system by identifying which Arks are currently active
     * - Used by _getArksData and _getWithdrawableArksData to populate cache data
     * - Essential for operations that need to iterate over or manage all active Arks
     * - Defined as virtual to be overridden by the FleetCommander contract and avoid calling it before it's required
     *
     * @custom:implementation-notes
     * - Must be implemented by the inheriting FleetCommander contract
     * - Should return a fresh array of addresses each time it's called
     * - Buffer Ark should NOT be included in this list (it's handled separately)
     * - Only truly active and operational Arks should be included
     *
     * @custom:related-functions
     * - _getArksData: Uses this function to get data for all active Arks
     * - _getWithdrawableArksData: Uses this function to identify withdrawable Arks
     * - _getAllArks: Combines these addresses with the buffer Ark
     */
    function _getActiveArksAddresses()
        internal
        view
        virtual
        returns (address[] memory)
    {}
}
