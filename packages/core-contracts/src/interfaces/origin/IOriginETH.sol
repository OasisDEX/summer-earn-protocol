// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOriginETH {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function vaultAddress() external view returns (address);
    function transfer(address to, uint256 amount) external;
    function rebaseOptIn() external;
    function rebaseState(address account) external view returns (uint8);
    function changeSupply(uint256 amount) external;
    function totalSupply() external view returns (uint256);
}
