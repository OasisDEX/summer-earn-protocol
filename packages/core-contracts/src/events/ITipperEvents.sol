// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Percentage} from "../types/Percentage.sol";

interface ITipperEvents {
    /**
     * @notice Emitted when the tip rate is updated
     * @param newTipRate The new tip rate value (in basis points)
     */
    event TipRateUpdated(uint256 newTipRate);

    /**
     * @notice Emitted when tips are accrued
     * @param tipAmount The amount of tips accrued in the underlying asset's smallest unit
     */
    event TipAccrued(uint256 tipAmount);

    /**
     * @notice Emitted when the tip jar address is updated
     * @param newTipJar The new address of the tip jar
     */
    event TipJarUpdated(address newTipJar);
}
