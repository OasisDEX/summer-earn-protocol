// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {IDecayController} from "../interfaces/IDecayController.sol";
/**
 * @title DecayController
 * @notice Manages decay updates for governance rewards and voting power
 */
abstract contract DecayController is IDecayController {
    ISummerToken public immutable summerToken;

    constructor(address _summerToken) {
        if (_summerToken == address(0)) {
            revert DecayController__ZeroAddress();
        }
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
