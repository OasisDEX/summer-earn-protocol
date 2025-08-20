// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IEscrow {
    function deposit(address asset, uint256 amount, bytes32 intentId) external;

    function withdraw(
        address asset,
        address to,
        bytes32 intentId
    ) external returns (uint256 amount);
}
