// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakingRewardsManager} from "./IStakingRewardsManager.sol";

/* @title IDecayableStakingRewardsManager
 * @notice Interface for the Decayable Staking Rewards Manager contract
 * @dev Manages staking and distribution of multiple reward tokens
 */
interface IDecayableStakingRewardsManager is IStakingRewardsManager {}
