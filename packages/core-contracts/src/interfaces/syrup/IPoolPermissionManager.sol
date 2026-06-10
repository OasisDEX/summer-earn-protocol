// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IPoolPermissionManager
/// @notice Interface for the Maple Syrup pool permission manager controlling lender access
interface IPoolPermissionManager {
    /// @notice Returns whether a lender is on a pool's allowlist
    /// @param poolManager The pool manager address
    /// @param lender The lender to check
    /// @return True if the lender is allowlisted
    function lenderAllowlist(
        address poolManager,
        address lender
    ) external view returns (bool);

    /// @notice Returns whether a lender holds a specific permission for a pool
    /// @param poolManager The pool manager address
    /// @param lender The lender to check
    /// @param permission The permission identifier
    /// @return True if the lender has the permission
    function hasPermission(
        address poolManager,
        address lender,
        bytes32 permission
    ) external view returns (bool);
}
