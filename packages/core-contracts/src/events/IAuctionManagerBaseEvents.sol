// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../types/CommonAuctionTypes.sol";

interface IAuctionManagerBaseEvents {
    /**
     * @notice Emitted when the auction configuration is updated
     * @param newConfig The new auction configuration
     */
    event AuctionDefaultParametersUpdated(BaseAuctionParameters newConfig);
}
