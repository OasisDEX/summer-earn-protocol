// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IPot {
    function dsr() external view returns (uint256);
    function chi() external view returns (uint256);
    function rho() external view returns (uint256);
}
