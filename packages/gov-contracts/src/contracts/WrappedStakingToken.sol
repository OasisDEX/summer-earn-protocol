// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20Wrapper} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title WrappedStakingToken
 * @notice A simple wrapper for the staking token that inherits from ERC20Wrapper
 * @dev This contract is used by GovernanceRewardsManager to wrap staking tokens when they are used as rewards
 */
contract WrappedStakingToken is ERC20Wrapper {
    constructor(
        address underlyingToken
    )
        ERC20(string.concat("Wrapped ", "Summer"), string.concat("w", "SUMR"))
        ERC20Wrapper(IERC20(underlyingToken))
    {}
}
