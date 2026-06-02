// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title IBenjiArkEvents
 * @notice Custom events for `BenjiArk`
 */
interface IBenjiArkEvents {
    /// @notice Emitted by `setDepositSlippage` after the cap is updated.
    /// @param oldDepositSlippage The previous `depositSlippage`
    /// @param newDepositSlippage The newly configured `depositSlippage`
    event DepositSlippageUpdated(
        Percentage oldDepositSlippage,
        Percentage newDepositSlippage
    );

    /// @notice Emitted when a SwapPool's whitelist status is updated by the curator.
    /// @param swapPool The SwapPool address whose status changed
    /// @param isWhitelisted The new whitelist status
    event SwapPoolWhitelisted(address indexed swapPool, bool isWhitelisted);
}
