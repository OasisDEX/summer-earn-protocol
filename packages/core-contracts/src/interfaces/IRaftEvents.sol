// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {SwapData} from "../types/RaftTypes.sol";


interface IRaftEvents {
    event ArkHarvested(address indexed ark, address rewardToken);
}
