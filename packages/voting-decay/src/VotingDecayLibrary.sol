// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";

library VotingDecayLibrary {
    using Math for uint256;

    uint256 public constant RAY = 1e27;
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    struct Account {
        uint256 decayIndex;
        uint256 lastUpdateTimestamp;
        uint256 decayRate;
        address delegateTo;
        uint256 decayFreeWindow;
    }

    function calculateDecayIndex(
        uint256 currentIndex,
        uint256 elapsedTime,
        uint256 decayRate,
        uint256 decayFreeWindow
    ) internal pure returns (uint256) {
        if (elapsedTime <= decayFreeWindow) {
            return currentIndex;
        }
        uint256 decayTime = elapsedTime - decayFreeWindow;
        uint256 yearFraction = (decayTime * RAY) / SECONDS_PER_YEAR;
        uint256 decayFactor = RAY - ((yearFraction * decayRate) / RAY);
        return (currentIndex * decayFactor) / RAY;
    }

    function applyDecayToVotingPower(uint256 originalVotingPower, uint256 decayIndex) internal pure returns (uint256) {
        return (originalVotingPower * decayIndex) / RAY;
    }

    function isValidDecayRate(uint256 rate) internal pure returns (bool) {
        return rate <= RAY;
    }
}
