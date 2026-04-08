// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StorageSlot} from "@summerfi/dependencies/openzeppelin-next/StorageSlot.sol";

import {IArk} from "../../interfaces/IArk.sol";
import {ArkData} from "../../types/FleetCommanderTypes.sol";
import {StorageSlots} from "./StorageSlots.sol";

/**
 * @title FleetCommanderCacheLib - Caching Utility Library
 * @dev This library provides the core logic for the caching mechanism used in the FleetCommander suite.
 *      It handles asset tracking, ark data management, rebalance flow calculations, and persistent state
 *      storage using transient-like behavior in storage slots.
 */
library FleetCommanderCacheLib {
    using StorageSlot for *;

    /**
     * @notice Checks if the FleetCommander is currently performing a transaction that includes a tip
     * @return bool True if collecting tips, false otherwise
     */
    function isCollectingTip() public view returns (bool) {
        return StorageSlots.TIP_TAKEN_STORAGE.asBoolean().tload();
    }

    /**
     * @notice Sets the isCollectingTip flag in storage
     * @param value The value to set the flag to
     */
    function setIsCollectingTip(bool value) public {
        StorageSlots.TIP_TAKEN_STORAGE.asBoolean().tstore(value);
    }

    /**
     * @notice Calculates the total assets across all given arks
     * @dev Checks if total assets are already cached. If so, returns the cached value.
     *      Otherwise, calculates the sum across all active arks and the buffer ark.
     * @param bufferArk The buffer ark instance
     * @param activeArks An array of addresses for all active arks
     * @return uint256 the sum of total assets across all arks
     */
    function totalAssets(
        IArk bufferArk,
        address[] memory activeArks
    ) public view returns (uint256) {
        bool isTotalAssetsCached = StorageSlots
            .IS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tload();
        if (isTotalAssetsCached) {
            return StorageSlots.TOTAL_ASSETS_STORAGE.asUint256().tload();
        }
        return sumTotalAssets(getAllArks(activeArks, bufferArk));
    }

    /**
     * @notice Calculates the total assets that can be withdrawn from the given arks
     * @dev Checks if withdrawable total assets are already cached. If so, returns the cached value.
     *      Otherwise, iterates through all arks and sums up their withdrawable assets.
     * @param bufferArk The buffer ark instance
     * @param activeArks An array of addresses for all active arks
     * @return withdrawableTotalAssetsSum The sum of withdrawable assets across all arks
     */
    function withdrawableTotalAssets(
        IArk bufferArk,
        address[] memory activeArks
    ) public view returns (uint256 withdrawableTotalAssetsSum) {
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

        IArk[] memory allArks = getAllArks(activeArks, bufferArk);
        for (uint256 i = 0; i < allArks.length; i++) {
            uint256 withdrawableAssets = allArks[i].withdrawableTotalAssets();
            if (withdrawableAssets > 0) {
                withdrawableTotalAssetsSum += withdrawableAssets;
            }
        }
    }

    /**
     * @notice Combines the active arks array with the buffer ark into a single IArk array
     * @param arks Array of active ark addresses
     * @param bufferArk The buffer ark instance
     * @return IArk[] A combined array of IArk interfaces
     */
    function getAllArks(
        address[] memory arks,
        IArk bufferArk
    ) internal pure returns (IArk[] memory) {
        IArk[] memory allArks = new IArk[](arks.length + 1);
        for (uint256 i = 0; i < arks.length; i++) {
            allArks[i] = IArk(arks[i]);
        }
        allArks[arks.length] = bufferArk;
        return allArks;
    }

    /**
     * @notice Sums the total assets across an array of arks
     * @param _arks An array of IArk interfaces
     * @return total The sum of total assets
     */
    function sumTotalAssets(
        IArk[] memory _arks
    ) internal view returns (uint256 total) {
        for (uint256 i = 0; i < _arks.length; i++) {
            total += _arks[i].totalAssets();
        }
    }

    /**
     * @notice Resets all caching-related storage slots
     * @dev This is called at the end of operations to ensure data freshness for subsequent calls.
     *      It flushes total assets, length indicators, and cached array data.
     */
    function flushCache() public {
        StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tstore(false);
        StorageSlots
            .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tstore(false);
        StorageSlots.WITHDRAWABLE_ARKS_LENGTH_STORAGE.asUint256().tstore(0);
        StorageSlots.ARKS_LENGTH_STORAGE.asUint256().tstore(0);
    }

    /**
     * @notice Retrieves and caches ArkData for all arks and the buffer ark
     * @dev If the total assets are already cached, it returns the data from the cache.
     *      Otherwise, it fetches total assets from each ark, populates the ArkData struct array,
     *      caches individual ark data, and caches the total assets sum.
     * @param bufferArk The buffer ark instance
     * @param activeArks Array of active ark addresses
     * @return _arksData An array of ArkData structs for all arks (buffer ark is at the end)
     */
    function getArksData(
        IArk bufferArk,
        address[] memory activeArks
    ) public returns (ArkData[] memory _arksData) {
        if (StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tload()) {
            return getAllArksDataFromCache();
        }

        _arksData = new ArkData[](activeArks.length + 1);
        uint256 totalAssetsSum = 0;

        for (uint256 i = 0; i < activeArks.length; i++) {
            uint256 arkAssets = IArk(activeArks[i]).totalAssets();
            _arksData[i] = ArkData(activeArks[i], arkAssets);
            totalAssetsSum += arkAssets;
        }

        uint256 bufferArkAssets = bufferArk.totalAssets();
        _arksData[activeArks.length] = ArkData(
            address(bufferArk),
            bufferArkAssets
        );
        totalAssetsSum += bufferArkAssets;

        cacheAllArksTotalAssets(totalAssetsSum);
        cacheAllArks(_arksData);
    }

    /**
     * @notice Calculates a storage slot key for a given prefix and index
     * @param prefix The prefix for the storage slot range
     * @param index The index within the range
     * @return bytes32 The calculated storage slot key
     */
    function getStorageSlot(
        bytes32 prefix,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(prefix, index));
    }

    /**
     * @notice Tracks rebalance inflow and outflow for specific arks
     * @dev Updates the total amount moved in or out of an ark during the current execution.
     *      Also ensures that max inflow/outflow limits are cached if not already present.
     * @param outflowArkAddress The address of the ark being disembarked from
     * @param inflowArkAddress The address of the ark being boarded
     * @param amount The amount moved
     * @return newInflowBalance Updated total inflow for the destination ark
     * @return newOutflowBalance Updated total outflow for the source ark
     * @return maxInflow The maximum allowed inflow for the destination ark
     * @return maxOutflow The maximum allowed outflow for the source ark
     */
    function cacheArkFlow(
        address outflowArkAddress,
        address inflowArkAddress,
        uint256 amount
    )
        public
        returns (
            uint256 newInflowBalance,
            uint256 newOutflowBalance,
            uint256 maxInflow,
            uint256 maxOutflow
        )
    {
        bytes32 inflowSlot = getStorageSlot(
            StorageSlots.ARK_INFLOW_BALANCE_STORAGE,
            uint256(uint160(inflowArkAddress))
        );
        bytes32 outflowSlot = getStorageSlot(
            StorageSlots.ARK_OUTFLOW_BALANCE_STORAGE,
            uint256(uint160(outflowArkAddress))
        );
        bytes32 maxInflowSlot = getStorageSlot(
            StorageSlots.ARK_MAX_INFLOW_BALANCE_STORAGE,
            uint256(uint160(inflowArkAddress))
        );
        bytes32 maxOutflowSlot = getStorageSlot(
            StorageSlots.ARK_MAX_OUTFLOW_BALANCE_STORAGE,
            uint256(uint160(outflowArkAddress))
        );

        maxInflow = maxInflowSlot.asUint256().tload();
        maxOutflow = maxOutflowSlot.asUint256().tload();

        if (maxInflow == 0) {
            maxInflow = IArk(inflowArkAddress).maxRebalanceInflow();
            maxInflowSlot.asUint256().tstore(maxInflow);
        }
        if (maxOutflow == 0) {
            maxOutflow = IArk(outflowArkAddress).maxRebalanceOutflow();
            maxOutflowSlot.asUint256().tstore(maxOutflow);
        }

        newInflowBalance = inflowSlot.asUint256().tload() + amount;
        newOutflowBalance = outflowSlot.asUint256().tload() + amount;

        inflowSlot.asUint256().tstore(newInflowBalance);
        outflowSlot.asUint256().tstore(newOutflowBalance);
    }

    /**
     * @notice Retrieves cached ArkData specifically for withdrawable arks
     * @return arksData Array of cached ArkData structs
     */
    function getWithdrawableArksDataFromCache()
        public
        view
        returns (ArkData[] memory arksData)
    {
        uint256 arksLength = StorageSlots
            .WITHDRAWABLE_ARKS_LENGTH_STORAGE
            .asUint256()
            .tload();
        arksData = new ArkData[](arksLength);
        for (uint256 i = 0; i < arksLength; i++) {
            address arkAddress = getStorageSlot(
                StorageSlots.WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE,
                i
            ).asAddress().tload();
            uint256 totalAssetsSum = getStorageSlot(
                StorageSlots.WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
                i
            ).asUint256().tload();
            arksData[i] = ArkData(arkAddress, totalAssetsSum);
        }
    }

    /**
     * @notice Retrieves cached ArkData for all arks
     * @return arksData Array of cached ArkData structs
     */
    function getAllArksDataFromCache()
        public
        view
        returns (ArkData[] memory arksData)
    {
        uint256 arksLength = StorageSlots
            .ARKS_LENGTH_STORAGE
            .asUint256()
            .tload();
        arksData = new ArkData[](arksLength);
        for (uint256 i = 0; i < arksLength; i++) {
            address arkAddress = getStorageSlot(
                StorageSlots.ARKS_ADDRESS_ARRAY_STORAGE,
                i
            ).asAddress().tload();
            uint256 totalAssetsSum = getStorageSlot(
                StorageSlots.ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
                i
            ).asUint256().tload();
            arksData[i] = ArkData(arkAddress, totalAssetsSum);
        }
    }

    /**
     * @notice Generic internal function to cache ark data into storage
     * @param arksData The array of ArkData structs to cache
     * @param totalAssetsPrefix Storage slot prefix for total assets
     * @param addressPrefix Storage slot prefix for ark addresses
     * @param lengthSlot Storage slot to store the array length
     */
    function cacheArks(
        ArkData[] memory arksData,
        bytes32 totalAssetsPrefix,
        bytes32 addressPrefix,
        bytes32 lengthSlot
    ) internal {
        for (uint256 i = 0; i < arksData.length; i++) {
            getStorageSlot(totalAssetsPrefix, i).asUint256().tstore(
                arksData[i].totalAssets
            );
            getStorageSlot(addressPrefix, i).asAddress().tstore(
                arksData[i].arkAddress
            );
        }
        lengthSlot.asUint256().tstore(arksData.length);
    }

    /**
     * @notice Caches data for all arks using the standard ark storage prefixes
     * @param _arksData The array of ArkData structs to cache
     */
    function cacheAllArks(ArkData[] memory _arksData) internal {
        cacheArks(
            _arksData,
            StorageSlots.ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
            StorageSlots.ARKS_ADDRESS_ARRAY_STORAGE,
            StorageSlots.ARKS_LENGTH_STORAGE
        );
    }

    /**
     * @notice Caches data for withdrawable arks using the withdrawable ark storage prefixes
     * @param _withdrawableArksData The array of ArkData structs to cache
     */
    function cacheWithdrawableArksTotalAssetsArray(
        ArkData[] memory _withdrawableArksData
    ) internal {
        cacheArks(
            _withdrawableArksData,
            StorageSlots.WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
            StorageSlots.WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE,
            StorageSlots.WITHDRAWABLE_ARKS_LENGTH_STORAGE
        );
    }

    /**
     * @notice Identifies, filters, and caches arks that have withdrawable assets
     * @dev Fetches all ark data, filters those with non-zero withdrawableTotalAssets,
     *      sorts them by total assets, and caches the result.
     * @param bufferArk The buffer ark instance
     * @param activeArks Array of active ark addresses
     */
    function getWithdrawableArksData(
        IArk bufferArk,
        address[] memory activeArks
    ) public {
        if (
            StorageSlots
                .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
                .asBoolean()
                .tload()
        ) {
            return;
        }
        ArkData[] memory _arksData = getArksData(bufferArk, activeArks);
        ArkData[] memory _withdrawableArksData = new ArkData[](
            _arksData.length
        );
        uint256 withdrawableTotalAssetsSum = 0;
        uint256 withdrawableCount = 0;

        for (uint256 i = 0; i < _arksData.length; i++) {
            uint256 withdrawableAssets = IArk(_arksData[i].arkAddress)
                .withdrawableTotalAssets();
            if (withdrawableAssets > 0) {
                _withdrawableArksData[withdrawableCount] = ArkData(
                    _arksData[i].arkAddress,
                    withdrawableAssets
                );
                withdrawableTotalAssetsSum += withdrawableAssets;
                withdrawableCount++;
            }
        }

        assembly {
            mstore(_withdrawableArksData, withdrawableCount)
        }
        cacheWithdrawableArksTotalAssets(withdrawableTotalAssetsSum);
        sortArkDataByTotalAssets(_withdrawableArksData);
        cacheWithdrawableArksTotalAssetsArray(_withdrawableArksData);
    }

    /**
     * @notice Updates the cached total assets sum and sets the cache indicator flag
     * @param totalAssetsSum The new total assets sum to cache
     */
    function cacheAllArksTotalAssets(uint256 totalAssetsSum) internal {
        StorageSlots.TOTAL_ASSETS_STORAGE.asUint256().tstore(totalAssetsSum);
        StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tstore(true);
    }

    /**
     * @notice Updates the cached withdrawable total assets sum and sets the cache indicator flag
     * @param withdrawableTotalAssetsSum The new withdrawable total assets sum to cache
     */
    function cacheWithdrawableArksTotalAssets(
        uint256 withdrawableTotalAssetsSum
    ) internal {
        StorageSlots.WITHDRAWABLE_ARKS_TOTAL_ASSETS_STORAGE.asUint256().tstore(
            withdrawableTotalAssetsSum
        );
        StorageSlots
            .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tstore(true);
    }

    /**
     * @notice Sorts an ArkData array in place by total assets (ascending)
     * @dev Uses a simple bubble sort implementation suitable for small fleet sizes.
     * @param arkDataArray The ArkData array to sort
     */
    function sortArkDataByTotalAssets(
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
