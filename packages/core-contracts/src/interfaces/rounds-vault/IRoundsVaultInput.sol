// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IRoundsVaultBase.sol";

/**
    @title IRoundsVaultInput

    @notice Marker interface for the Input flavor of `RoundsVaultBase`. Users deposit the target
    vault's underlying asset and receive ERC-1155 receipts. Once the keeper settles the round, the
    target-vault shares produced by the settlement deposit become the exchange asset that holders of
    past-round receipts can redeem against.

    @dev The function surface is identical to `IRoundsVaultBase`; this interface exists so consumers
    can statically distinguish Input-flavor vaults from Output-flavor vaults (`IRoundsVaultOutput`).
    Flavor-specific behavior lives in `RoundsVaultInput`'s `_operate` and `_getFallbackExchangeRate`.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultInput is IRoundsVaultBase {
    // Empty on purpose: the public ABI is fully described by IRoundsVaultBase. Flavor-specific
    // behavior is in the implementation's `_operate` and `_getFallbackExchangeRate` overrides.
}
