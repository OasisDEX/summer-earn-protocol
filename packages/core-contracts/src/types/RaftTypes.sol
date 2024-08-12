// SPDX-License-Identifier: BUSL-1.1

import {Percentage} from "@summerfi/dutch-auction/src/lib/Percentage.sol";
import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";

pragma solidity 0.8.26;

struct AuctionConfig {
    uint40 duration;
    uint256 startPrice;
    uint256 endPrice;
    Percentage kickerRewardPercentage;
    DecayFunctions.DecayType decayType;
}
