// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IStakingReceiver
/// @notice Interface a contract must implement to receive tokens from `withdrawToAndCall`
interface IStakingReceiver {
    /// @notice Called by the staking contract after transferring withdrawn tokens to this receiver
    /// @param token The staking token withdrawn
    /// @param from The account the tokens were withdrawn from
    /// @param value The amount of tokens received
    /// @param data Arbitrary data forwarded from the caller
    /// @return The function selector confirming receipt (magic value)
    function onWithdrawReceived(
        IERC20 token,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}
