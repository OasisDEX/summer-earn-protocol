// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IAdapter {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external;

    function withdraw(address asset, uint256 amount, address to) external;

    function returnEscrowedYield(address asset, uint256 amount) external;

    function totalAssets() external view returns (uint256);
}
