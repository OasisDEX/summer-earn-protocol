// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @notice Minimal interface for Morpho VaultV2 (MetaMorpho V2) used by integrations.
/// @dev Kept intentionally small to avoid pulling in GPL-licensed sources.
interface IVaultV2 {
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
    function isAdapter(address adapter) external view returns (bool);

    // Gates
    function canSendShares(address account) external view returns (bool);
    function canReceiveAssets(address account) external view returns (bool);
}
