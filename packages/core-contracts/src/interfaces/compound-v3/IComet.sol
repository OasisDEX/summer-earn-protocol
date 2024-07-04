// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IComet {
    event Supply(address indexed from, address indexed dst, uint amount);
    event Withdraw(address indexed src, address indexed to, uint amount);

    function supply(address asset, uint amount) virtual external;
    function withdraw(address asset, uint amount) virtual external;
}