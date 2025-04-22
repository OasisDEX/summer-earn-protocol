// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDistributor {
    function toggleOperator(address user, address operator) external;
}
