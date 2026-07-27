// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IArmZapper
/// @notice Interface for the zapper that deposits native ETH into the Lido ARM
interface IArmZapper {
    /// @notice Deposit ETH to LidoARM and receive shares
    /// @return shares The amount of ARM LP shares sent to the depositor
    function deposit() external payable returns (uint256 shares);
}
