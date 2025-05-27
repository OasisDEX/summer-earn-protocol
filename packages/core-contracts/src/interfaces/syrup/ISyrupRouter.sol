// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ISyrupRouter {
    event DepositData(
        address indexed owner,
        uint256 amount,
        bytes32 depositData
    );

    struct AuthData {
        uint256 bitmap;
        uint256 deadline;
        uint8 auth_v;
        bytes32 auth_r;
        bytes32 auth_s;
    }

    function authorizeAndDeposit(
        uint256 bitmap_,
        uint256 deadline_,
        uint8 auth_v,
        bytes32 auth_r,
        bytes32 auth_s,
        uint256 amount_,
        bytes32 depositData_
    ) external returns (uint256 shares_);

    function deposit(
        uint256 amount,
        bytes32 depositData
    ) external returns (uint256 shares_);
}
