// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title StorageSlots
 * @dev This library defines storage slots using the technique described in EIP-1967.
 * @notice The subtraction of 1 from the keccak256 hash is used to avoid potential conflicts
 * with Solidity's default storage slot allocation for state variables.
 * @dev For more information, see: https://eips.ethereum.org/EIPS/eip-1967
 */
library StorageSlots {
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    /// @notice Transient storage slot for the cached total assets value
    bytes32 public constant TOTAL_ASSETS_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.totalAssets")) - 1
            )
        ) & ~bytes32(uint256(0xff));
    /// @notice Transient storage slot for the flag indicating whether total assets are cached
    bytes32 public constant IS_TOTAL_ASSETS_CACHED_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.isTotalAssetsCached")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    /// @notice Transient storage slot for the cached per-Ark total assets array
    bytes32 public constant ARKS_TOTAL_ASSETS_ARRAY_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.arksTotalAssetsArray")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    /// @notice Transient storage slot for the cached active-Ark address array
    bytes32 public constant ARKS_ADDRESS_ARRAY_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.arksAddressArray")) -
                    1
            )
        ) & ~bytes32(uint256(0xff));
    /// @notice Transient storage slot for the cached count of active Arks
    bytes32 public constant ARKS_LENGTH_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.arksLength")) - 1
            )
        ) & ~bytes32(uint256(0xff));

    /// @notice Transient storage slot for the cached total assets of withdrawable Arks
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
    /// @notice Transient storage slot for the cached per-Ark total assets array of withdrawable Arks
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

    /// @notice Transient storage slot for the cached withdrawable-Ark address array
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
    /// @notice Transient storage slot for the cached count of withdrawable Arks
    bytes32 public constant WITHDRAWABLE_ARKS_LENGTH_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.withdrawableArksLength")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    /// @notice Transient storage slot for the flag indicating whether withdrawable-Arks total assets are cached
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
    /// @notice Transient storage slot for the per-Ark inflow balance accumulated during a rebalance
    bytes32 public constant ARK_INFLOW_BALANCE_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.arkInflowBalance")) -
                    1
            )
        ) & ~bytes32(uint256(0xff));

    /// @notice Transient storage slot for the per-Ark outflow balance accumulated during a rebalance
    bytes32 public constant ARK_OUTFLOW_BALANCE_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage.arkOutflowBalance")) -
                    1
            )
        ) & ~bytes32(uint256(0xff));

    /// @notice Transient storage slot for the per-Ark maximum allowed inflow balance during a rebalance
    bytes32 public constant ARK_MAX_INFLOW_BALANCE_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.arkMaxInflowBalance")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    /// @notice Transient storage slot for the per-Ark maximum allowed outflow balance during a rebalance
    bytes32 public constant ARK_MAX_OUTFLOW_BALANCE_STORAGE =
        keccak256(
            abi.encode(
                uint256(
                    keccak256("fleetCommander.storage.arkMaxOutflowBalance")
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));
    /// @notice Transient storage slot for the flag indicating a tip is currently being collected
    bytes32 public constant TIP_TAKEN_STORAGE =
        keccak256(
            abi.encode(
                uint256(keccak256("fleetCommander.storage._isCollectingTip")) -
                    1
            )
        ) & ~bytes32(uint256(0xff));
}
