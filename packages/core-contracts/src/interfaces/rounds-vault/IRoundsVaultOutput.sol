// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IRoundsVaultBase.sol";

/**
    @title IRoundsVaultOutput

    @notice Marker interface for the Output flavor of `RoundsVaultBase`. Users deposit target vault
    shares and receive ERC-1155 receipts. Once the keeper settles the round, the target vault's
    underlying asset produced by the settlement redeem becomes the exchange asset that holders of
    past-round receipts can redeem against.

    @dev The function surface is identical to `IRoundsVaultBase`; this interface exists so consumers
    can statically distinguish Output-flavor vaults from Input-flavor vaults (`IRoundsVaultInput`).
    Flavor-specific behavior lives in `RoundsVaultOutput`'s `_operate` and `_getFallbackExchangeRate`.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultOutput is IRoundsVaultBase {
    // Empty on purpose: the public ABI is fully described by IRoundsVaultBase. Flavor-specific
    // behavior is in the implementation's `_operate` and `_getFallbackExchangeRate` overrides.
}
