// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title YieldPocket
 * @author Summer
 * @notice Holds excess USDC (e.g. yield) separate from user deposits in the main TestYieldToken contract.
 * @dev Owner is the TestYieldToken contract. Used to isolate yield/surplus USDC from pending deposits
 *      so amounts can be processed without mixing. Owner may withdraw to main contract for withdrawals.
 */
contract YieldPocket is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The USDC token held in this pocket
    // forge-lint: disable-next-line(screaming-snake-case-immutable)
    IERC20 public immutable usdc;

    /// @param _usdc Address of the USDC token
    /// @param _owner Owner address (typically the parent TestYieldToken)
    constructor(address _usdc, address _owner) Ownable(_owner) {
        usdc = IERC20(_usdc);
    }

    /**
     * @notice Withdraw USDC from the pocket to a recipient.
     * @param to Recipient address.
     * @param amount Amount to withdraw (6 decimals).
     */
    function withdraw(address to, uint256 amount) external onlyOwner {
        usdc.safeTransfer(to, amount);
    }
}
