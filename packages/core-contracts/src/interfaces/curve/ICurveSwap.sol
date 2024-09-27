// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface ICurveSwap {
    function last_price(uint256 i) external view returns (uint256);
    function ema_price(uint256 i) external view returns (uint256);
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy
    ) external returns (uint256);
}
