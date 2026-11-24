// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IStakedCap
 * @notice Interface for the Staked Cap (stcUSD) ERC4626 vault
 */
interface IStakedCap is IERC4626 {
    function notify() external;

    function lockedProfit() external view returns (uint256);

    function lastNotify() external view returns (uint256);

    function lockDuration() external view returns (uint256);
}
