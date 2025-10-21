// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IProtocolFeeTokenHandlerEvents} from "../interfaces/IProtocolFeeTokenHandlerEvents.sol";
import {IProtocolFeeTokenHandlerErrors} from "../interfaces/IProtocolFeeTokenHandlerErrors.sol";

/**
 * @title ProtocolFeeTokenHandler
 * @notice Abstract base contract for managing protocol fee token payments
 * @dev Provides reusable functionality for bridge adapters that support ERC20 token fee payments.
 *      This contract can be inherited by any bridge adapter that needs to handle protocol token fees.
 */
abstract contract ProtocolFeeTokenHandler is
    IProtocolFeeTokenHandlerEvents,
    IProtocolFeeTokenHandlerErrors
{
    using SafeERC20 for IERC20;

    /// @notice ERC20 token used to pay bridge protocol fees when supported by the adapter
    address public protocolFeeToken;

    /**
     * @notice Sets the ERC20 token used to pay protocol fees
     * @param token The ERC20 token address (e.g., ZRO). Use address(0) to disable token-fee mode.
     * @custom:access Only callable by authorized addresses (implementation must override _requireFeeAuthorization)
     */
    function setProtocolFeeToken(address token) external {
        _requireFeeAuthorization();
        protocolFeeToken = token;
        emit ProtocolFeeTokenConfigured(token);
    }

    /**
     * @notice Handles protocol token fee collection and validation
     * @param operationId The operation ID for this transaction
     * @param feePayer The address that will pay the protocol token fees
     * @param tokenFeeRequired The amount of protocol tokens required
     */
    function _collectProtocolTokenFee(
        bytes32 operationId,
        address feePayer,
        uint256 tokenFeeRequired
    ) internal {
        if (protocolFeeToken == address(0)) {
            revert ProtocolTokenNotConfigured();
        }

        if (tokenFeeRequired > 0) {
            IERC20(protocolFeeToken).safeTransferFrom(
                feePayer,
                address(this),
                tokenFeeRequired
            );

            emit ProtocolFeeCollected(
                operationId,
                feePayer,
                protocolFeeToken,
                tokenFeeRequired
            );
        }
    }

    /**
     * @notice Ensures sufficient allowance for protocol fee token spending
     * @param requiredAmount The amount of tokens needed for the operation
     * @param spender The address that will spend the tokens
     */
    function _ensureSufficientAllowance(
        uint256 requiredAmount,
        address spender
    ) internal {
        if (protocolFeeToken == address(0)) return;

        uint256 currentAllowance = IERC20(protocolFeeToken).allowance(
            address(this),
            spender
        );
        if (currentAllowance < requiredAmount) {
            IERC20(protocolFeeToken).forceApprove(spender, requiredAmount);
        }
    }

    /**
     * @notice Authorization check for fee-related operations
     * @dev Must be implemented by derived contracts to define authorization logic
     * @custom:throws Unauthorized if caller is not authorized
     */
    function _requireFeeAuthorization() internal view virtual;
}
