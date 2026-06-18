// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title ISecuritizeOnRamp
 * @notice Minimal interface for Securitize's per-fund on-ramp (subscription) contract, registered
 *         in the DSToken's service registry under id 16384.
 * @dev Subscriptions are operator-authorized: an EXCHANGE/ISSUER key signs an EIP-712
 *      `ExecutePreApprovedTransaction` whose `data` is an internal `subscribe(...)` call. The
 *      on-ramp verifies the signer's role, pulls the liquidity token from the investor wallet,
 *      forwards it (minus fee) to the fund custodian, and MINTS the DSToken to the investor in the
 *      same transaction. There is no on-chain off-ramp — redemptions settle off-chain.
 */
interface ISecuritizeOnRamp {
    /// @notice Operator-signed authorization for the on-ramp to execute `data` against `destination`
    ///         (in practice an internal `subscribe(...)`), bound to an investor nonce.
    struct ExecutePreApprovedTransaction {
        string senderInvestor;
        address destination;
        bytes data;
        uint256 nonce;
    }

    /// @notice Executes a Securitize-signed pre-approved transaction (a subscription). The signature
    ///         must recover to an EXCHANGE/ISSUER role holder; the on-ramp then runs `txData.data`.
    /// @param signature The operator's EIP-712 signature over `txData`
    /// @param txData The pre-approved transaction (destination, `subscribe` calldata, investor nonce)
    function executePreApprovedTransaction(
        bytes calldata signature,
        ExecutePreApprovedTransaction calldata txData
    ) external;

    /// @notice The liquidity (stablecoin) token the on-ramp pulls on subscription.
    /// @return The liquidity token address
    function liquidityToken() external view returns (address);

    /// @notice The fund custodian wallet that receives subscription liquidity.
    /// @return The fund custodian wallet address
    function custodianWallet() external view returns (address);

    /// @notice The Securitize single-source NAV provider the on-ramp prices subscriptions with.
    /// @return The NAV provider address
    function navProvider() external view returns (address);

    /// @notice Per-investor nonce consumed by `executePreApprovedTransaction`.
    /// @param investorId The Securitize investor identifier
    /// @return The next nonce for `investorId`
    function nonceByInvestor(
        string calldata investorId
    ) external view returns (uint256);
}
