// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./IRoundsVaultBase.sol";

/**
    @title IRoundsVaultInput

    @notice The IRoundsInputVault contract allows users to deposit funds into this contract while the
    target vault is locked, and receipts are minted to the users for this deposits. Upon round completion, the
    funds are transferred to the target vault and the corresponding shares are collected.

    Users can then exchange their receipts from previous rounds for the corresponding shares held in this vault.

    @author Roberto Cano <robercano>
 */
interface IRoundsVaultInput is IRoundsVaultBase {
    // Empty on purpose, as the interface is the same as the IRoundsVaultBase
    // The main changes are in the implementation itself
}
