// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IComet {
    event Supply(address indexed from, address indexed dst, uint256 amount);
    event Withdraw(address indexed src, address indexed to, uint256 amount);

    function supply(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
}
