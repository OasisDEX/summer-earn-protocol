// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ICurveSwap {
    function last_price(uint256 i) external view returns (uint256);
    function ema_price(uint256 i) external view returns (uint256);
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
    function coins(uint256 i) external view returns (address);
}
