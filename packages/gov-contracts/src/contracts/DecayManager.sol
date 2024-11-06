// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ISummerToken.sol";

/**
 * @title DecayManager
 * @notice Manages decay updates for governance rewards and voting power
 */
abstract contract DecayManager {
    ISummerToken public immutable summerToken;

    constructor(address _summerToken) {
        require(_summerToken != address(0), "DecayManager: zero address");
        summerToken = ISummerToken(_summerToken);
    }

    /**
     * @notice Modifier to update decay before executing a function
     * @param account Address to update decay for
     */
    modifier updateDecay(address account) {
        if (account != address(0)) {
            summerToken.updateDecayFactor(account);
        }
        _;
    }
}
