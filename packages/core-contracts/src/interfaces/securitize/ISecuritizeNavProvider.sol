// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title ISecuritizeNavProvider
 * @notice Minimal interface for Securitize's single-source NAV provider (the TSSO root source).
 * @dev `rate()` is the fund NAV denominated in the fund's asset decimals (e.g. 6 for USDC-based
 *      funds). It is operator-set (`setRate`) and carries NO freshness signal (no timestamp), which
 *      is why the Ark prices via the RedStone `AggregatorV3Interface` feed (same upstream value,
 *      plus `updatedAt` and the TSSO signature chain). The Ark does not call `rate()` directly; the
 *      on-ramp's own pricing is bounded indirectly by the Ark's post-mint minted-shares check.
 */
interface ISecuritizeNavProvider {
    /// @notice Current NAV rate, in the fund's asset decimals.
    /// @return The current NAV rate, denominated in the fund's asset decimals.
    function rate() external view returns (uint256);
}
