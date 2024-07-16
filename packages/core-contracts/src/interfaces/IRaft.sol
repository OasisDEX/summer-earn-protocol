// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SwapData} from "../types/RaftTypes.sol";
import {IRaftEvents} from "./IRaftEvents.sol";

/**
 * @title IRaft
 * @notice ...
 */
interface IRaft is IRaftEvents {
    function harvestAndSwap(address ark, address rewardToken, SwapData calldata swapData) external;
    function harvest(address ark, address rewardToken) external;
    function swap(SwapData calldata swapData) external;
}