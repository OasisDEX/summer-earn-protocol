// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ITokenRecovery} from "../interfaces/ITokenRecovery.sol";

/**
 * @title TokenRecovery
 * @notice Abstract base contract providing token recovery functionality
 * @dev This contract provides reusable token recovery logic for contracts that need
 *      to recover stuck tokens (ETH or ERC20). Access control is handled through
 *      abstract functions that must be implemented by derived contracts.
 */
abstract contract TokenRecovery is ReentrancyGuard, ITokenRecovery {
    using SafeERC20 for IERC20;

    /**
     * @notice Recover tokens held by this contract
     * @dev Emergency recovery function for stuck tokens. This function allows
     *      authorized users to recover any tokens (ETH or ERC20) that may have
     *      been sent to this contract accidentally or become stuck due to
     *      failed operations.
     * @param asset Token to recover (address(0) for native ETH, or ERC20 token address)
     * @param to Recipient of the recovered tokens (must not be zero address)
     * @param amount Amount to sweep (must not exceed contract balance)
     * @custom:throws InvalidParams if recipient address is zero
     * @custom:throws InsufficientBalance if requested amount exceeds available balance
     * @custom:throws TransferFailed if native ETH transfer fails
     * @custom:emits TokensRecovered when tokens are successfully recovered
     * @custom:access Only callable by authorized addresses (implementation defined)
     * @custom:security Protected by reentrancy guard to prevent reentrancy attacks
     */
    function sweep(
        address asset,
        address to,
        uint256 amount
    ) external nonReentrant {
        if (to == address(0)) revert InvalidRecoveryParams();

        // Check authorization - must be implemented by derived contracts
        _requireRecoveryAuthorization();

        _recoverToken(asset, to, amount);
    }

    /**
     * @notice Internal recovery function for use by derived contracts
     * @dev This function can be called by derived contracts to recover tokens
     *      without going through the external sweep function. Useful for
     *      internal recovery operations.
     * @param asset Token to recover (address(0) for native ETH, or ERC20 token address)
     * @param to Recipient of the recovered tokens
     * @param amount Amount to recover
     * @custom:throws InsufficientBalance if requested amount exceeds available balance
     * @custom:throws TransferFailed if native ETH transfer fails
     * @custom:emits TokensRecovered when tokens are successfully recovered
     */
    function _recoverToken(address asset, address to, uint256 amount) internal {
        if (asset == address(0)) {
            // Handle native ETH
            if (address(this).balance < amount) revert InsufficientBalance();
            Address.sendValue(payable(to), amount);
        } else {
            // Handle ERC20 tokens
            uint256 balance = IERC20(asset).balanceOf(address(this));
            if (balance < amount) revert InsufficientBalance();
            IERC20(asset).safeTransfer(to, amount);
        }

        emit TokensRecovered(asset, amount, to);
    }

    /**
     * @notice Check if the caller is authorized to perform token recovery
     * @dev This function must be implemented by derived contracts to define
     *      the access control logic for token recovery operations.
     * @custom:throws Unauthorized if caller is not authorized
     */
    function _requireRecoveryAuthorization() internal view virtual;
}
