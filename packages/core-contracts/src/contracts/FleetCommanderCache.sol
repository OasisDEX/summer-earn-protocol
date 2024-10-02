// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {StorageSlot} from "../../lib/openzeppelin-next/StorageSlot.sol";

import {IArk} from "../interfaces/IArk.sol";
import {ArkData} from "../types/FleetCommanderTypes.sol";
import {StorageSlots} from "./libraries/StorageSlots.sol";

contract FleetCommanderCache {
    using StorageSlot for *;

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
     * @notice Retrieves an array of all Arks, including regular Arks and the buffer Ark
     * @dev This function creates a new array that includes all regular Arks and appends the buffer Ark at the end
     * @return An array of IArk interfaces representing all Arks in the system
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
     * @notice Calculates the sum of total assets across all provided Arks
     * @dev This function iterates through the provided array of Arks and accumulates their total assets
     * @param _arks An array of IArk interfaces representing the Arks to sum assets from
     * @return total The sum of total assets across all provided Arks
     */
    function _sumTotalAssets(
        IArk[] memory _arks
    ) private view returns (uint256 total) {
        for (uint256 i = 0; i < _arks.length; i++) {
            total += _arks[i].totalAssets();
        }
    }

    /**
     * @notice Flushes the cache for all arks and related data
     * @dev This function resets the cached data for all arks and related data
     *      to ensure that the next call to `totalAssets` or `withdrawableTotalAssets`
     *      recalculates the values based on the current state of the arks.
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
     * @notice Retrieves the data (address, totalAssets) for all arks and the buffer ark
     * @return _arksData An array of ArkData structs containing the ark addresses and their total assets
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

        // Sort array by total assets
        _sortArkDataByTotalAssets(_arksData);
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
     * @notice Retrieves data for withdrawable arks, using pre-fetched data for all arks
     * @dev This function filters and sorts withdrawable arks by total assets
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
     * @notice Sorts the ArkData structs based on their total assets in ascending order
     * @dev This function implements a simple bubble sort algorithm
     * @param arkDataArray An array of ArkData structs to be sorted
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
