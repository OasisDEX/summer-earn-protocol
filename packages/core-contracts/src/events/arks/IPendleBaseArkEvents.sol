// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title IPendleBaseArkEvents
 * @notice Interface for events emitted by Pendle Ark contracts
 * @dev This interface defines events related to market rollovers, slippage updates, and oracle duration changes
 */
interface IPendleBaseArkEvents {
    /**
     * @notice Emitted when the Pendle market is rolled over to a new market
     * @dev This event is triggered during the rollover process when the current market expires
     * @param newMarket The address of the new Pendle market after rollover
     */
    event MarketRolledOver(address indexed newMarket);

    /**
     * @notice Emitted when the slippage tolerance is updated
     * @dev This event is triggered when the governor changes the slippage settings
     * @param newSlippagePercentage The new slippage tolerance represented as a Percentage
     */
    event SlippageUpdated(Percentage newSlippagePercentage);

    /**
     * @notice Emitted when the oracle duration is updated
     * @dev This event is triggered when the governor changes the oracle duration settings
     * @param newOracleDuration The new oracle duration in seconds
     */
    event OracleDurationUpdated(uint32 newOracleDuration);
}
