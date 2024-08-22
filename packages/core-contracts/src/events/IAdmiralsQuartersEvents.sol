// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IAdmiralsQuartersEvents {
    event TokensDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event TokensWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event FleetEntered(
        address indexed user,
        address indexed fleetCommander,
        uint256 inputAmount,
        uint256 sharesReceived
    );
    event FleetExited(
        address indexed user,
        address indexed fleetCommander,
        uint256 withdrawnAmount,
        uint256 outputAmount
    );
    event Swapped(
        address indexed user,
        address indexed fromToken,
        address indexed toToken,
        uint256 fromAmount,
        uint256 toAmount
    );
    event TokensRescued(
        address indexed token,
        address indexed to,
        uint256 amount
    );
}
