// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IRaft} from "../interfaces/IRaft.sol";
import {IArk} from "../interfaces/IArk.sol";
import {SwapData} from "../types/RaftTypes.sol";

/**
 * @custom:see IRaft
 */
contract Raft is IRaft {
    function harvestAndSwap(address ark, address rewardToken, SwapData calldata swapData) external {

    }
    function harvest(address ark, address rewardToken) public {
        IArk(ark).harvest(rewardToken);

        emit ArkHarvested(ark, rewardToken);
    }
    function swap(SwapData calldata swapData) public {

    }
}