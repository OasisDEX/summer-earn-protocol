// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IPot {
    function dsr() external view returns (uint256);
    function chi() external view returns (uint256);
    function rho() external view returns (uint256);
}
