// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IPermit2, IAllowanceTransfer, ISignatureTransfer} from "../interfaces/permit2/IPermit2.sol";

/**
 * @title Permit2Consumer
 * @notice Abstract base contract for contracts that pull ERC20 tokens from users
 *         via Permit2's AllowanceTransfer mechanism.
 *
 * @dev ## What is Permit2?
 *      Permit2 (deployed by Uniswap) is a canonical, singleton allowance contract.
 *      Instead of giving an individual spending contract an unlimited ERC20 approval,
 *      users approve Permit2 once, and then grant time-limited, amount-limited
 *      sub-allowances to specific spenders inside Permit2 itself. This keeps
 *      exposure bounded: if the spending contract is compromised, only the
 *      sub-allowance (not the full token balance) is at risk.
 *
 * @dev ## AllowanceTransfer vs SignatureTransfer
 *      This contract uses the *AllowanceTransfer* path:
 *        - User calls `token.approve(permit2Address, amount)` once (standard ERC20).
 *        - User grants a sub-allowance via `PERMIT2.approve(token, spender, amount, expiration)`
 *          or via a signed `permit` message.
 *      Calling `_pullFunds` then invokes `PERMIT2.transferFrom`, which atomically
 *      checks and debits the sub-allowance before moving tokens to this contract.
 *
 * @dev ## User prerequisites before any pull can succeed
 *      1. `token.approve(address(PERMIT2), type(uint256).max)` — grant Permit2 the
 *         ability to move the token on the user's behalf.
 *      2. `PERMIT2.approve(token, address(this), amount, expiration)` — grant this
 *         contract a sub-allowance inside Permit2. Alternatively, the keeper can
 *         submit a signed `PermitSingle` message to `PERMIT2.permit(...)`.
 *      Both steps must be completed before the first execution.
 *
 * @dev ## Inheriting contracts
 *      Call `Permit2Consumer(permit2Address)` in your constructor. The address is
 *      validated to be non-zero at construction time. `PERMIT2` is an immutable so
 *      it costs only a `PUSH32` at runtime with no storage reads.
 *
 *      Use `_pullFunds(owner, token, amount)` anywhere you need to debit tokens
 *      from a user that has set up the Permit2 allowance described above.
 */
abstract contract Permit2Consumer {
    /// @notice The canonical Permit2 contract used for all allowance-based transfers.
    IPermit2 public immutable PERMIT2;

    /**
     * @notice Reverts when `amount` exceeds `type(uint160).max`, the cap imposed
     *         by Permit2's `AllowanceTransfer` interface.
     * @param amount The amount that overflowed.
     */
    error AmountOverflowsUint160(uint256 amount);

    /**
     * @notice Reverts when the provided Permit2 address is the zero address.
     */
    error InvalidPermit2Address();

    /**
     * @notice Reverts when a Permit2 message names a `spender` other than this
     *         contract. Protects users from accidentally signing approvals that
     *         empower the wrong relayer.
     */
    error InvalidPermit2Spender(address expected, address actual);

    /**
     * @notice Reverts when a Permit2 message's `token` does not match the token
     *         the caller intends to consume.
     */
    error InvalidPermit2Token(address expected, address actual);

    /**
     * @notice Reverts when a Permit2 SignatureTransfer message's `amount` does
     *         not match the amount the caller intends to pull.
     */
    error InvalidPermit2Amount(uint256 expected, uint256 actual);

    /**
     * @notice Reverts when `_applyPermit2Allowance`'s underlying `PERMIT2.permit`
     *         call fails AND the (token, spender) sub-allowance is still below
     *         the amount the owner signed for. Allows mempool front-runs that
     *         result in the signed sub-allowance being live to proceed
     *         silently; rejects every other permit failure mode.
     */
    error Permit2AllowanceNotSet(uint160 required, uint160 actual);

    /**
     * @param _permit2 Address of the deployed Permit2 singleton. Must be non-zero.
     */
    constructor(address _permit2) {
        if (_permit2 == address(0)) revert InvalidPermit2Address();
        PERMIT2 = IPermit2(_permit2);
    }

    /**
     * @notice Pulls `amount` of `token` from `owner` into this contract using
     *         Permit2's AllowanceTransfer path.
     * @dev Reverts with `AmountOverflowsUint160` when `amount > type(uint160).max`
     *      because Permit2 stores allowances as `uint160`. Normal token amounts
     *      fit comfortably within this range; the check guards against accidental
     *      overflow when the amount originates from a wider type.
     * @param owner  The address whose Permit2 sub-allowance is debited.
     * @param token  The ERC20 token (or ERC4626 share) to transfer.
     * @param amount The number of tokens to pull. Must not exceed `type(uint160).max`.
     * @return The amount actually transferred (equal to `amount`).
     */
    function _pullFunds(
        address owner,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        if (amount > type(uint160).max) revert AmountOverflowsUint160(amount);
        PERMIT2.transferFrom(owner, address(this), uint160(amount), token);
        return amount;
    }

    /**
     * @notice Applies an `AllowanceTransfer.PermitSingle` signed by `owner`,
     *         setting (or refreshing) the (token, this, amount, expiration)
     *         sub-allowance inside Permit2.
     * @dev Reverts `InvalidPermit2Spender` if `permitSingle.spender` is not this
     *      contract. The `PERMIT2.permit` call is wrapped in try/catch so a
     *      mempool front-run that lifts and submits the user's signed permit
     *      independently (causing the in-tx call to fail with `InvalidNonce`)
     *      does not abort the caller — provided the resulting sub-allowance is
     *      at least what was signed for. Any other failure mode falls through
     *      to `Permit2AllowanceNotSet`.
     * @param owner The address that signed `permitSingle`.
     * @param permitSingle The PermitSingle data the owner signed.
     * @param signature EIP-712 signature over `permitSingle`.
     */
    function _applyPermit2Allowance(
        address owner,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    ) internal {
        if (permitSingle.spender != address(this)) {
            revert InvalidPermit2Spender(address(this), permitSingle.spender);
        }
        try PERMIT2.permit(owner, permitSingle, signature) {} catch {
            (uint160 amount, , ) = PERMIT2.allowance(
                owner,
                permitSingle.details.token,
                address(this)
            );
            if (amount < permitSingle.details.amount) {
                revert Permit2AllowanceNotSet(
                    permitSingle.details.amount,
                    amount
                );
            }
        }
    }

    /**
     * @notice Pulls `amount` of `token` from `owner` using a Permit2
     *         `SignatureTransfer.permitTransferFrom` one-shot signature.
     * @dev Validates that the signed `token` and `amount` match the caller's
     *      intent (revert `InvalidPermit2Token` / `InvalidPermit2Amount` on
     *      mismatch). Recipient is always `address(this)`.
     * @param owner The address that signed `permitData`.
     * @param token The expected `permitData.permitted.token`.
     * @param amount The expected `permitData.permitted.amount` and the amount
     *               requested for transfer.
     * @param permitData The PermitTransferFrom data the owner signed.
     * @param signature EIP-712 signature over `permitData`.
     */
    function _pullFundsWithPermit2(
        address owner,
        address token,
        uint256 amount,
        ISignatureTransfer.PermitTransferFrom calldata permitData,
        bytes calldata signature
    ) internal {
        if (address(permitData.permitted.token) != token) {
            revert InvalidPermit2Token(
                token,
                address(permitData.permitted.token)
            );
        }
        if (permitData.permitted.amount != amount) {
            revert InvalidPermit2Amount(amount, permitData.permitted.amount);
        }
        PERMIT2.permitTransferFrom(
            permitData,
            ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: amount
            }),
            owner,
            signature
        );
    }
}
