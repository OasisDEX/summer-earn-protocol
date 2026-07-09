// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// @notice Minimal ERC-7575 vault surface used by the gateway (external share token).
///         The full ERC-7575 vault ERC-165 id (0x2f0a18c5) is reported by the implementation.
interface IERC7575Minimal {
    /// @notice The address of the ERC-20 share received on deposit. May be external to the vault.
    function share() external view returns (address shareTokenAddress);

    /// @notice The vault's deposit asset, per ERC-4626.
    function asset() external view returns (address assetTokenAddress);
}
