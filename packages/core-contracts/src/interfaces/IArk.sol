// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../events/IArkEvents.sol";
import "../types/ArkTypes.sol";
import "../types/Percentage.sol";
import {IArkAccessManaged} from "./IArkAccessManaged.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

interface IArk is IArkAccessManaged, IArkEvents {

    /* FUNCTIONS - PUBLIC */

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

}
