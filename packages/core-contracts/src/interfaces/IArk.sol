// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IArkAccessManaged} from "./IArkAccessManaged.sol";
import "../types/Percentage.sol";
import "../types/ArkTypes.sol";
import "../events/IArkEvents.sol";

interface IArk is IArkEvents {
    /* FUNCTIONS - PUBLIC */

    /// @notice Returns max allocation for this ark
    function maxAllocation() external view returns (uint256);

    /// @notice Returns latest deposit cap set for this Ark
    function depositCap() external view returns (uint256);

    /// @notice Returns the current underlying balance of the Ark (token precision)
    function totalAssets() external view returns (uint256);

    /// @notice Returns the current rate of the Ark (RAY precision)
    function rate() external view returns (uint256);

    function harvest() external;

    /* FUNCTIONS - EXTERNAL - COMMANDER */

    function board(uint256 amount) external;

    function disembark(uint256 amount) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external;

    function setRaft(address newRaft) external;

    function setMaxAllocation(uint256 newMaxAllocation) external;
}
