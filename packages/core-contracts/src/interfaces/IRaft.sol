// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SwapData} from "../types/RaftTypes.sol";

/**
 * @title IRaft
 * @notice ...
 */
interface IRaft {
    function harvestAndSwap(address ark, SwapData calldata swapData) external;
    function harvest(address ark) external;
    function swap(SwapData calldata swapData) external;
}