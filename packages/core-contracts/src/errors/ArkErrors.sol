// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

error CannotRemoveCommanderFromArkWithAssets();
error CannotAddCommanderToArkWithCommander();
error CannotDeployArkWithoutConfigurationManager();
error CannotDeployArkWithoutRaft();
error CannotDeployArkWithoutToken();
error CannotDeployArkWithEmptyName();
error InvalidVaultAddress();
error ERC4626AssetMismatch();
error CannotUseKeeperDataWithUnrestrictedWithdrawal();
error CannotUseUnrestrictedWithdrawalWithoutKeeperData();
