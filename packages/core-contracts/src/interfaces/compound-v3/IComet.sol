// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IComet {
    event Supply(address indexed from, address indexed dst, uint256 amount);
    event Withdraw(address indexed src, address indexed to, uint256 amount);

    function supply(address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;

    function getSupplyRate(uint256 utilization) external view returns (uint64);

    function getUtilization() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);
}
