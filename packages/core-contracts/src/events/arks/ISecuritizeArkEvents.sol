// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

interface ISecuritizeArkEvents {
    /// @notice Emitted by `requestWithdrawal` after DSToken shares are sent to the Securitize
    ///         custodian for off-chain redemption.
    /// @param shares Shares transferred to the custodian wallet
    /// @param expectedAssets Underlying asset amount the keeper requested (informational)
    event SharesSentForRedemption(uint256 shares, uint256 expectedAssets);

    /// @notice Emitted when the Securitize custodian wallet is rotated.
    /// @param oldWallet The previous custodian wallet
    /// @param newWallet The new custodian wallet
    event CustodianWalletUpdated(address oldWallet, address newWallet);

    /// @notice Emitted whenever `setArkFrozen` is called.
    /// @param isFrozen The new frozen state
    /// @param frozenTotalAssets The total-assets snapshot reported while frozen
    event ArkIsFrozenUpdated(bool isFrozen, uint256 frozenTotalAssets);

    /// @notice Emitted by `setSweepSlippage` after the cap is updated.
    /// @param oldSweepSlippage The previous sweep slippage
    /// @param newSweepSlippage The new sweep slippage
    event SweepSlippageUpdated(
        Percentage oldSweepSlippage,
        Percentage newSweepSlippage
    );

    /// @notice Emitted by `setDepositSlippage` after the cap is updated.
    /// @param oldDepositSlippage The previous deposit slippage
    /// @param newDepositSlippage The new deposit slippage
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );

    /// @notice Emitted by `setSubscriptionFeeTolerance` after the on-ramp fee tolerance is updated.
    /// @param oldTolerance The previous subscription-fee tolerance
    /// @param newTolerance The new subscription-fee tolerance
    event SubscriptionFeeToleranceUpdated(
        Percentage oldTolerance,
        Percentage newTolerance
    );

    /// @notice Emitted when `_board` subscribes by relaying a Securitize-signed
    ///         `executePreApprovedTransaction` through the on-ramp.
    /// @param assets Base-asset amount subscribed
    /// @param sharesReceived DSTokens minted to the Ark in the same transaction
    event SubscribedViaOnRamp(uint256 assets, uint256 sharesReceived);
}
