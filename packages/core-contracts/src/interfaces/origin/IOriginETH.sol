// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOriginETH {
    function mint(address to, uint256 amount, uint256 minShares) external;
}
