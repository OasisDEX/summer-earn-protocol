// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IArmZapper {
    /// @notice Deposit ETH to LidoARM and receive shares
    /// @return shares The amount of ARM LP shares sent to the depositor
    function deposit() external payable returns (uint256 shares);
}
