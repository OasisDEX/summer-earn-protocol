// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPoolPermissionManager {
    function lenderAllowlist(
        address poolManager,
        address lender
    ) external view returns (bool);

    function hasPermission(
        address poolManager,
        address lender,
        bytes32 permission
    ) external view returns (bool);
}
