// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title ISecuritizeOnRamp
 * @notice Minimal interface for Securitize's per-fund on-ramp (subscription/swap) contract.
 * @dev Registered in the DSToken's service registry under id 16384 (`DEPRECATED_SECURITIZE_SWAP`
 *      in the latest DS Protocol sources, but live for VBILL/ACRED/STAC). `swap` performs an
 *      ATOMIC primary-market subscription: it pulls the liquidity token (USDC) from the caller,
 *      forwards it (minus fee) to the fund's custodian wallet, and MINTS fresh DSTokens to the
 *      caller at `navProvider().rate()` in the same transaction. The caller must be a registered
 *      investor wallet. There is no on-chain off-ramp — redemptions settle off-chain.
 */
interface ISecuritizeOnRamp {
    /**
     * @notice Atomically swaps the liquidity token (e.g. USDC) for freshly issued DSTokens.
     * @param _liquidityAmount Liquidity-token amount to subscribe (fee is taken from this)
     * @param _minOutAmount Minimum DSToken amount to receive (slippage control)
     */
    function swap(uint256 _liquidityAmount, uint256 _minOutAmount) external;

    /**
     * @notice Quotes the DSToken amount for a given liquidity amount at the current NAV.
     * @return dsTokenAmount DSTokens that would be issued
     * @return rate The NAV rate used
     * @return fee The fee taken from `_liquidityAmount`
     */
    function calculateDsTokenAmount(
        uint256 _liquidityAmount
    ) external view returns (uint256 dsTokenAmount, uint256 rate, uint256 fee);

    /// @notice The Securitize single-source NAV provider used to price subscriptions.
    function navProvider() external view returns (address);

    /// @notice The fund's custodian wallet receiving subscription liquidity.
    function custodianWallet() external view returns (address);

    /// @notice The liquidity (stablecoin) token accepted by `swap`.
    function liquidityToken() external view returns (address);

    /// @notice Whether investor-initiated `swap` subscriptions are currently enabled.
    function investorSubscriptionEnabled() external view returns (bool);

    /// @notice Minimum `_liquidityAmount` accepted by `swap`/`subscribe`.
    function minSubscriptionAmount() external view returns (uint256);
}
