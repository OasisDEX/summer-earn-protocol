// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./VotingDecayMath.sol";

library VotingDecayLibrary {
    using VotingDecayMath for uint256;

    uint256 public constant WAD = 1e18;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    enum DecayFunction {
        Linear,
        Exponential
    }

    struct DecayInfo {
        uint256 retentionFactor;
        uint40 lastUpdateTimestamp;
        address delegateTo;
    }

    function calculateRetentionFactor(
        uint256 currentRetentionFactor,
        uint256 elapsedSeconds,
        uint256 decayRatePerSecond,
        uint256 decayFreeWindow,
        DecayFunction decayFunction
    ) internal pure returns (uint256) {
        if (elapsedSeconds <= decayFreeWindow) return currentRetentionFactor;

        uint256 decayTime = elapsedSeconds - decayFreeWindow;

        if (decayFunction == DecayFunction.Linear) {
            return
                currentRetentionFactor.linearDecay(
                    decayRatePerSecond,
                    decayTime
                );
        } else {
            return
                currentRetentionFactor.exponentialDecay(
                    decayRatePerSecond,
                    decayTime
                );
        }
    }

    function applyDecay(
        uint256 originalValue,
        uint256 retentionFactor
    ) internal pure returns (uint256) {
        return VotingDecayMath.mulDiv(originalValue, retentionFactor, WAD);
    }

    function isValidDecayRate(uint256 rate) internal pure returns (bool) {
        return rate <= WAD;
    }
}
