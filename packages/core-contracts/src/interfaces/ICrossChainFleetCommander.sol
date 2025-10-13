// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFleetCommander} from "./IFleetCommander.sol";
import {CrossChainFleetCommanderParams} from "../types/CrossChainFleetCommanderTypes.sol";

/**
 * @title ICrossChainFleetCommander
 * @notice Interface for CrossChain FleetCommander with cooldown protection
 * @dev Extends IFleetCommander with cooldown functionality to prevent MEV attacks
 */
interface ICrossChainFleetCommander is IFleetCommander {
    /*//////////////////////////////////////////////////////////////
                            COOLDOWN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the cooldown period between deposit and withdraw/redeem
     * @return period The cooldown period in seconds
     */
    function getCooldownPeriod() external view returns (uint256 period);

    /**
     * @notice Get the timestamp when a user can next withdraw/redeem
     * @param user The address of the user
     * @return timestamp The timestamp when the user can next withdraw/redeem, or 0 if no previous deposit
     */
    function getNextWithdrawTimestamp(
        address user
    ) external view returns (uint256 timestamp);

    /**
     * @notice Check if a user can withdraw/redeem (cooldown has passed)
     * @param user The address of the user
     * @return canWithdrawNow True if the user can withdraw/redeem now
     */
    function canWithdraw(
        address user
    ) external view returns (bool canWithdrawNow);

    /**
     * @notice Set the cooldown period for deposits
     * @dev Only callable by the curator when not paused
     * @param newCooldownPeriod The new cooldown period in seconds
     */
    function setCooldownPeriod(uint256 newCooldownPeriod) external;
}
