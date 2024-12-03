// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StorageSlot} from "@summerfi/dependencies/openzeppelin-next/StorageSlot.sol";

import {IArk} from "../interfaces/IArk.sol";
import {ArkData} from "../types/FleetCommanderTypes.sol";
import {StorageSlots} from "./libraries/StorageSlots.sol";

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
     * @dev Calculates the total assets across all arks
     * @param arks Array of ark addresses
     * @param bufferArk The buffer ark instance
     * @return total The sum of total assets across all arks
     * @custom:internal-logic
     * - Checks if total assets are cached
     * - If cached, returns the cached value
     * - If not cached, calculates the sum of total assets across all arks
     * @custom:effects
     * - No state changes
     * @custom:security-considerations
     * - Relies on accurate reporting of total assets by individual arks
     * - Caching mechanism must be properly managed to ensure data freshness
     * - Assumes no changes in total assets throughout the execution of function that use this cache
     */
    function _totalAssets(
        address[] memory arks,
        IArk bufferArk
    ) internal view returns (uint256 total) {
        bool isTotalAssetsCached = StorageSlots
            .IS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tload();
        if (isTotalAssetsCached) {
            return StorageSlots.TOTAL_ASSETS_STORAGE.asUint256().tload();
        }
        return _sumTotalAssets(_getAllArks(arks, bufferArk));
    }

    /**
     * @dev Calculates the total assets of withdrawable arks
     * @param arks Array of ark addresses
     * @param bufferArk The buffer ark instance
     * @param isArkWithdrawable Mapping to check if an ark is withdrawable
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
     * - Depends on the correctness of the isArkWithdrawable mapping
     */
    function _withdrawableTotalAssets(
        address[] memory arks,
        IArk bufferArk,
        mapping(address => bool) storage isArkWithdrawable
    ) internal view returns (uint256 withdrawableTotalAssets) {
        bool isWithdrawableTotalAssetsCached = StorageSlots
            .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tload();
        if (isWithdrawableTotalAssetsCached) {
            return
                StorageSlots
                    .WITHDRAWABLE_ARKS_TOTAL_ASSETS_STORAGE
                    .asUint256()
                    .tload();
        }

        IArk[] memory allArks = _getAllArks(arks, bufferArk);
        for (uint256 i = 0; i < allArks.length; i++) {
            if (
                i == allArks.length - 1 ||
                isArkWithdrawable[address(allArks[i])]
            ) {
                withdrawableTotalAssets += allArks[i].totalAssets();
            }
        }
    }

    /**
     * @dev Retrieves an array of all Arks, including regular Arks and the buffer Ark
     * @param arks Array of regular ark addresses
     * @param bufferArk The buffer ark instance
     * @return An array of IArk interfaces representing all Arks in the system
     * @custom:internal-logic
     * - Creates a new array with length of regular arks plus one (for buffer ark)
     * - Populates the array with regular arks and appends the buffer ark
     * @custom:effects
     * - No state changes
     * @custom:security-considerations
     * - Ensures the buffer ark is always included at the end of the array
     */
    function _getAllArks(
        address[] memory arks,
        IArk bufferArk
    ) private pure returns (IArk[] memory) {
        IArk[] memory allArks = new IArk[](arks.length + 1);
        for (uint256 i = 0; i < arks.length; i++) {
            allArks[i] = IArk(arks[i]);
        }
        allArks[arks.length] = IArk(bufferArk);
        return allArks;
    }

    /**
     * @dev Calculates the sum of total assets across all provided Arks
     * @param _arks An array of IArk interfaces representing the Arks to sum assets from
     * @return total The sum of total assets across all provided Arks
     * @custom:internal-logic
     * - Iterates through the provided array of Arks
     * - Accumulates the total assets from each Ark
     * @custom:effects
     * - No state changes
     * @custom:security-considerations
     * - Relies on accurate reporting of total assets by individual arks
     * - Vulnerable to integer overflow if total assets become extremely large
     */
    function _sumTotalAssets(
        IArk[] memory _arks
    ) private view returns (uint256 total) {
        for (uint256 i = 0; i < _arks.length; i++) {
            total += _arks[i].totalAssets();
        }
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
        StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tstore(false);
        StorageSlots
            .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tstore(false);
        StorageSlots.WITHDRAWABLE_ARKS_LENGTH_STORAGE.asUint256().tstore(0);
        StorageSlots.ARKS_LENGTH_STORAGE.asUint256().tstore(0);
    }

    /**
     * @dev Retrieves the data (address, totalAssets) for all arks and the buffer ark
     * @param arks Array of regular ark addresses
     * @param bufferArk The buffer ark instance
     * @return _arksData An array of ArkData structs containing the ark addresses and their total assets
     * @custom:internal-logic
     * - Initializes data for all arks including the buffer ark
     * - Populates data for regular arks and buffer ark
     * - Sorts the array by total assets
     * - Caches the total assets and ark data
     * - buffer ark is always at the end of the array
     * @custom:effects
     * - Caches total assets and ark data
     * - Modifies storage slots related to ark data
     * @custom:security-considerations
     * - Relies on accurate reporting of total assets by individual arks
     * - Sorting mechanism must be efficient and correct
     */
    function _getArksData(
        address[] memory arks,
        IArk bufferArk
    ) internal returns (ArkData[] memory _arksData) {
        // Initialize data for all arks
        _arksData = new ArkData[](arks.length + 1); // +1 for buffer ark
        uint256 totalAssets = 0;

        // Populate data for regular arks
        for (uint256 i = 0; i < arks.length; i++) {
            uint256 arkAssets = IArk(arks[i]).totalAssets();
            _arksData[i] = ArkData(arks[i], arkAssets);
            totalAssets += arkAssets;
        }

        // Add buffer ark data
        uint256 bufferArkAssets = bufferArk.totalAssets();
        _arksData[arks.length] = ArkData(address(bufferArk), bufferArkAssets);
        totalAssets += bufferArkAssets;

        _cacheAllArksTotalAssets(totalAssets);
        _cacheAllArks(_arksData);
    }

    /**
     * @notice Retrieves a storage slot based on the provided prefix and index
     * @param prefix The prefix for the storage slot
     * @param index The index for the storage slot
     * @return bytes32 The storage slot value
     */
    function _getStorageSlot(
        bytes32 prefix,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(prefix, index));
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
        uint256 arksLength = StorageSlots
            .WITHDRAWABLE_ARKS_LENGTH_STORAGE
            .asUint256()
            .tload();
        arksData = new ArkData[](arksLength);
        for (uint256 i = 0; i < arksLength; i++) {
            address arkAddress = _getStorageSlot(
                StorageSlots.WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE,
                i
            ).asAddress().tload();
            uint256 totalAssets = _getStorageSlot(
                StorageSlots.WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
                i
            ).asUint256().tload();
            arksData[i] = ArkData(arkAddress, totalAssets);
        }
    }

    /**
     * @notice Caches the data for all arks in the specified storage slots
     * @param arksData The array of ArkData structs containing the ark addresses and their total assets
     * @param totalAssetsPrefix The prefix for the ark total assets storage slot
     * @param addressPrefix The prefix for the ark addresses storage slot
     * @param lengthSlot The storage slot containing the number of arks
     */
    function _cacheArks(
        ArkData[] memory arksData,
        bytes32 totalAssetsPrefix,
        bytes32 addressPrefix,
        bytes32 lengthSlot
    ) internal {
        for (uint256 i = 0; i < arksData.length; i++) {
            _getStorageSlot(totalAssetsPrefix, i).asUint256().tstore(
                arksData[i].totalAssets
            );
            _getStorageSlot(addressPrefix, i).asAddress().tstore(
                arksData[i].arkAddress
            );
        }
        lengthSlot.asUint256().tstore(arksData.length);
    }

    /**
     * @notice Caches the data for all arks in the specified storage slots
     * @param _arksData The array of ArkData structs containing the ark addresses and their total assets
     */
    function _cacheAllArks(ArkData[] memory _arksData) internal {
        _cacheArks(
            _arksData,
            StorageSlots.ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
            StorageSlots.ARKS_ADDRESS_ARRAY_STORAGE,
            StorageSlots.ARKS_LENGTH_STORAGE
        );
    }

    /**
     * @notice Caches the data for all withdrawable arks in the specified storage slots
     * @param _withdrawableArksData The array of ArkData structs containing the ark addresses and their total assets
     */
    function _cacheWithdrawableArksTotalAssetsArray(
        ArkData[] memory _withdrawableArksData
    ) internal {
        _cacheArks(
            _withdrawableArksData,
            StorageSlots.WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
            StorageSlots.WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE,
            StorageSlots.WITHDRAWABLE_ARKS_LENGTH_STORAGE
        );
    }

    /**
     * @dev Retrieves and processes data for withdrawable arks
     * @param arks Array of ark addresses
     * @param bufferArk The buffer ark instance
     * @param isArkWithdrawable Mapping to check if an ark is withdrawable
     * @custom:internal-logic
     * - Fetches data for all arks using _getArksData
     * - Filters arks based on withdrawability
     * - Accumulates total assets of withdrawable arks
     * - Resizes the array to remove empty slots
     * - Sorts the withdrawable arks by total assets
     * - Caches the processed data
     * @custom:effects
     * - Modifies storage by caching withdrawable arks data
     * - Updates the total assets of withdrawable arks in storage
     * @custom:security-considerations
     * - Assumes the isArkWithdrawable mapping is correctly maintained
     * - Uses assembly for array resizing, which bypasses Solidity's safety checks
     * - Relies on the correctness of _getArksData, _cacheWithdrawableArksTotalAssets,
     *   _sortArkDataByTotalAssets, and _cacheWithdrawableArksTotalAssetsArray functions
     */
    function _getWithdrawableArksData(
        address[] memory arks,
        IArk bufferArk,
        mapping(address => bool) storage isArkWithdrawable
    ) internal {
        ArkData[] memory _arksData = _getArksData(arks, bufferArk);
        // Initialize data for withdrawable arks
        ArkData[] memory _withdrawableArksData = new ArkData[](
            _arksData.length
        );
        uint256 withdrawableTotalAssets = 0;
        uint256 withdrawableCount = 0;

        // Populate data for withdrawable arks
        for (uint256 i = 0; i < _arksData.length; i++) {
            if (
                i == _arksData.length - 1 ||
                isArkWithdrawable[_arksData[i].arkAddress]
            ) {
                _withdrawableArksData[withdrawableCount] = _arksData[i];

                withdrawableTotalAssets += _arksData[i].totalAssets;
                withdrawableCount++;
            }
        }

        // Resize _withdrawableArksData array to remove empty slots
        assembly {
            mstore(_withdrawableArksData, withdrawableCount)
        }
        _cacheWithdrawableArksTotalAssets(withdrawableTotalAssets);
        _sortArkDataByTotalAssets(_withdrawableArksData);
        _cacheWithdrawableArksTotalAssetsArray(_withdrawableArksData);
    }

    /**
     * @notice Caches the total assets for all arks in the specified storage slot
     * @param totalAssets The total assets to cache
     */
    function _cacheAllArksTotalAssets(uint256 totalAssets) internal {
        StorageSlots.TOTAL_ASSETS_STORAGE.asUint256().tstore(totalAssets);
        StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tstore(true);
    }

    /**
     * @notice Caches the total assets for all withdrawable arks in the specified storage slot
     * @param withdrawableTotalAssets The total assets to cache
     */
    function _cacheWithdrawableArksTotalAssets(
        uint256 withdrawableTotalAssets
    ) internal {
        StorageSlots.WITHDRAWABLE_ARKS_TOTAL_ASSETS_STORAGE.asUint256().tstore(
            withdrawableTotalAssets
        );
        StorageSlots
            .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tstore(true);
    }

    /**
     * @dev Sorts the ArkData structs based on their total assets in ascending order
     * @param arkDataArray An array of ArkData structs to be sorted
     * @custom:internal-logic
     * - Implements a simple bubble sort algorithm
     * - Compares adjacent elements and swaps them if they are in the wrong order
     * - Continues until no more swaps are needed
     * @custom:effects
     * - Modifies the input array in-place, sorting it by totalAssets
     * @custom:security-considerations
     * - Time complexity is O(n^2), which may be inefficient for large arrays
     * - Assumes that the totalAssets values fit within uint256 and won't overflow during comparisons
     */
    function _sortArkDataByTotalAssets(
        ArkData[] memory arkDataArray
    ) internal pure {
        for (uint256 i = 0; i < arkDataArray.length; i++) {
            for (uint256 j = i + 1; j < arkDataArray.length; j++) {
                if (arkDataArray[i].totalAssets > arkDataArray[j].totalAssets) {
                    (arkDataArray[i], arkDataArray[j]) = (
                        arkDataArray[j],
                        arkDataArray[i]
                    );
                }
            }
        }
    }
}
