// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {FleetCommanderParams} from "../../src/types/FleetCommanderTypes.sol";

/**
 * @title FleetCommanderWithdrawalFeeTestHarness
 * @notice Test harness that exposes internal functions for testing withdrawal fee functionality
 * @dev This contract inherits from FleetCommander and exposes internal functions as public
 *      so they can be called directly in tests
 */
contract FleetCommanderWithdrawalFeeTestHarness is FleetCommander {
    constructor(FleetCommanderParams memory params) FleetCommander(params) {}

    /**
     * @notice Exposes the internal _calculateWithdrawalFee function for testing
     * @param assets The amount of assets to calculate fee for
     * @return The calculated withdrawal fee
     */
    function calculateWithdrawalFee(
        uint256 assets
    ) external view returns (uint256) {
        return _calculateWithdrawalFee(assets);
    }

    /**
     * @notice Exposes the internal _calculateWithdrawalFeeShares function for testing
     * @param shares The amount of shares to calculate fee for
     * @return The calculated withdrawal fee in shares
     */
    function calculateWithdrawalFeeShares(
        uint256 shares
    ) external view returns (uint256) {
        return _calculateWithdrawalFeeShares(shares);
    }
}
