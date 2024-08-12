// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./DutchAuctionMath.sol";

library DecayFunctions {
    enum DecayType {
        Linear,
        Exponential
    }

    function calculateDecay(
        DecayType decayType,
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration
    ) internal pure returns (uint256) {
        if (decayType == DecayType.Linear) {
            return
                DutchAuctionMath.linearDecay(
                    startPrice,
                    endPrice,
                    timeElapsed,
                    totalDuration
                );
        } else {
            return
                DutchAuctionMath.exponentialDecay(
                    startPrice,
                    endPrice,
                    timeElapsed,
                    totalDuration
                );
        }
    }
}
