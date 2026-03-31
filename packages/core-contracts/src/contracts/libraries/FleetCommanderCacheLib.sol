// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {StorageSlot} from "@summerfi/dependencies/openzeppelin-next/StorageSlot.sol";

import {IArk} from "../../interfaces/IArk.sol";
import {ArkData} from "../../types/FleetCommanderTypes.sol";
import {StorageSlots} from "./StorageSlots.sol";

library FleetCommanderCacheLib {
    using StorageSlot for *;

    function isCollectingTip() public view returns (bool) {
        return StorageSlots.TIP_TAKEN_STORAGE.asBoolean().tload();
    }

    function setIsCollectingTip(bool value) public {
        StorageSlots.TIP_TAKEN_STORAGE.asBoolean().tstore(value);
    }

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

    function sumTotalAssets(
        IArk[] memory _arks
    ) internal view returns (uint256 total) {
        for (uint256 i = 0; i < _arks.length; i++) {
            total += _arks[i].totalAssets();
        }
    }

    function flushCache() public {
        StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tstore(false);
        StorageSlots
            .IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE
            .asBoolean()
            .tstore(false);
        StorageSlots.WITHDRAWABLE_ARKS_LENGTH_STORAGE.asUint256().tstore(0);
        StorageSlots.ARKS_LENGTH_STORAGE.asUint256().tstore(0);
    }

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

    function getStorageSlot(
        bytes32 prefix,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(prefix, index));
    }

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

    function cacheAllArks(ArkData[] memory _arksData) internal {
        cacheArks(
            _arksData,
            StorageSlots.ARKS_TOTAL_ASSETS_ARRAY_STORAGE,
            StorageSlots.ARKS_ADDRESS_ARRAY_STORAGE,
            StorageSlots.ARKS_LENGTH_STORAGE
        );
    }

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

    function cacheAllArksTotalAssets(uint256 totalAssetsSum) internal {
        StorageSlots.TOTAL_ASSETS_STORAGE.asUint256().tstore(totalAssetsSum);
        StorageSlots.IS_TOTAL_ASSETS_CACHED_STORAGE.asBoolean().tstore(true);
    }

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
