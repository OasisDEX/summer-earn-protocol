// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IComet {
    event Supply(address indexed from, address indexed dst, uint amount);
    event Withdraw(address indexed src, address indexed to, uint amount);

    function supply(address asset, uint amount) external;
    function withdraw(address asset, uint amount) external;

    function balanceOf(address owner) external view returns (uint256);

    function getSupplyRate(uint utilization) external view returns (uint64);
    function getUtilization() external view returns (uint);
}
