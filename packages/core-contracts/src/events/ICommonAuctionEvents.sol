// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../types/CommonAuctionTypes.sol";

interface ICommonAuctionEvents {
    /**
     * @notice Emitted when the auction configuration is updated
     * @param newConfig The new auction configuration
     */
    event AuctionDefaultParametersUpdated(AuctionDefaultParameters newConfig);
}
