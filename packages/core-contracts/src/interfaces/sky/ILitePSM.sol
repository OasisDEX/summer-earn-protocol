// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ILitePSM {
    function sellGem(address usr, uint256 gemAmt) external returns (uint256);
    function buyGem(address usr, uint256 gemAmt) external returns (uint256);
    function to18ConversionFactor() external view returns (uint256);
    function gem() external view returns (address);
}
