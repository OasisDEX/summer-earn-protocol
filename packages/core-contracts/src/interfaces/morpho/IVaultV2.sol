// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @title IVaultV2
/// @notice Minimal interface for Morpho VaultV2 (MetaMorpho V2) used by integrations.
/// @dev Kept intentionally small to avoid pulling in GPL-licensed sources.
interface IVaultV2 {
    /// @notice Returns the address of the vault's current liquidity adapter
    /// @return The liquidity adapter address
    function liquidityAdapter() external view returns (address);
    /// @notice Returns the encoded liquidity data passed to the liquidity adapter
    /// @return The liquidity data
    function liquidityData() external view returns (bytes memory);
    /// @notice Returns whether an address is a registered adapter of the vault
    /// @param adapter The address to check
    /// @return True if the address is a registered adapter
    function isAdapter(address adapter) external view returns (bool);

    // Gates
    /// @notice Returns whether an account is allowed to send (transfer out) vault shares
    /// @param account The account to check
    /// @return True if the account may send shares
    function canSendShares(address account) external view returns (bool);
    /// @notice Returns whether an account is allowed to receive vault assets
    /// @param account The account to check
    /// @return True if the account may receive assets
    function canReceiveAssets(address account) external view returns (bool);
}
