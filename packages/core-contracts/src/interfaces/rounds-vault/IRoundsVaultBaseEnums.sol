// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IRoundsVaultBaseEnums {
    enum BaseVaultType {
        Input, /// @notice The vault accepts underlying assets and deposits them into the target vault.
        Output /// @notice The vault accepts target vault shares and redeems them for underlying assets.
    }
}
