// SPDX-License-Identifier: BUSL-1.1

import {DecayFunctions} from "@summerfi/dutch-auction/src/DecayFunctions.sol";
import {Percentage} from "@summerfi/percentage/src/Percentage.sol";

pragma solidity 0.8.26;

struct AuctionDefaultParameters {
    uint40 duration;
    uint256 startPrice;
    uint256 endPrice;
    Percentage kickerRewardPercentage;
    DecayFunctions.DecayType decayType;
}
