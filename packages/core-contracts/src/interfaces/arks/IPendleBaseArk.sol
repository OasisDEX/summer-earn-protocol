// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPendleBaseArkErrors} from "../../errors/arks/IPendleBaseArkErrors.sol";
import {IPendleBaseArkEvents} from "../../events/arks/IPendleBaseArkEvents.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

interface IPendleBaseArk is IPendleBaseArkEvents, IPendleBaseArkErrors {
    /**
     * @notice Sets the slippage tolerance, can only be called by the governor
     * @param _newSlippagePercentage New slippage tolerance
     */
    function setSlippagePercentage(Percentage _newSlippagePercentage) external;

    /**
     * @notice Sets the oracle duration
     * @param _newOracleDuration New oracle duration, can only be called by the governor
     */
    function setOracleDuration(uint32 _newOracleDuration) external;

    /**
     * @notice Sets the next market
     * @param _nextMarket The address of the next market, can only be called by the governor
     */
    function setNextMarket(address _nextMarket) external;
}
