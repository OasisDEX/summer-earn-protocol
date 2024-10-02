// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

library StorageSlots {
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant TOTAL_ASSETS_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.totalAssets")) - 1
            )
        ) & ~bytes32(uint256(0xff));
    bytes32 public constant IS_TOTAL_ASSETS_CACHED_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.isTotalAssetsCached")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    bytes32 public constant ARKS_TOTAL_ASSETS_ARRAY_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.arksTotalAssetsArray")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    bytes32 public constant ARKS_ADDRESS_ARRAY_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.arksAddressArray")) -
                    1
            )
        ) & ~bytes32(uint256(0xff));
    bytes32 public constant ARKS_LENGTH_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.arksLength")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    bytes32 public constant WITHDRAWABLE_ARKS_TOTAL_ASSETS_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        "fleetCommander.storage.withdrawableArksTotalAssets"
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    bytes32 public constant WITHDRAWABLE_ARKS_TOTAL_ASSETS_ARRAY_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        "fleetCommander.storage.withdrawableArksTotalAssetsArray"
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    bytes32 public constant WITHDRAWABLE_ARKS_ADDRESS_ARRAY_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        "fleetCommander.storage.withdrawableArksAddressArray"
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    bytes32 public constant WITHDRAWABLE_ARKS_LENGTH_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.withdrawableArksLength")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    bytes32 public constant IS_WITHDRAWABLE_ARKS_TOTAL_ASSETS_CACHED_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256(
                        "fleetCommander.storage.isWithdrawableArksTotalAssetsCached"
                    )
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
}
