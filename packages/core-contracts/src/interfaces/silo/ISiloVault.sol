// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title ISiloVault
/// @notice Minimal interface for a Silo meta-vault (ERC4626) that allocates across silos
interface ISiloVault is IERC4626 {
    /// @notice Returns the address of the vault's incentives module
    /// @return The incentives module address
    function INCENTIVES_MODULE() external view returns (address);
}
