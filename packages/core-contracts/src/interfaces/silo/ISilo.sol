// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title ISilo
/// @notice Minimal interface for a Silo V2 lending market (ERC4626 vault)
interface ISilo is IERC4626 {
    /// @notice Returns the address of the silo's configuration contract
    /// @return The SiloConfig address
    function siloConfig() external view returns (address);
}
