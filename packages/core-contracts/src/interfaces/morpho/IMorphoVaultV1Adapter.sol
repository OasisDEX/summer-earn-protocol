// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @notice Minimal interface for Morpho's MorphoVaultV1Adapter used as a VaultV2 liquidity adapter.
/// @dev Kept intentionally small to avoid pulling in GPL-licensed sources.
interface IMorphoVaultV1Adapter {
    function morphoVaultV1() external view returns (address);
}
