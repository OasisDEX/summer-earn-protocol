// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title IBaseSwapArkEvents
 * @notice Events emitted by swap-based Ark contracts
 */
interface IBaseSwapArkEvents {
    /**
     * @notice Emitted when the allowed swap slippage is updated
     * @param newSlippagePercentage The new maximum slippage percentage applied to swaps
     */
    event SlippageUpdated(Percentage newSlippagePercentage);
}
