// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IArkAccessControl} from "./IArkAccessControl.sol";
import "../types/Percentage.sol";
import "../types/ArkTypes.sol";
import "./IArkEvents.sol";

interface IArk is IArkAccessControl, IArkEvents {
    /* FUNCTIONS - PUBLIC */
    function balance() external view returns (uint256);
    function harvest() external;

    /* FUNCTIONS - EXTERNAL - COMMANDER */
    function board(uint256 amount) external;
    function disembark(uint256 amount) external;

    /* FUNCTIONS - EXTERNAL - GOVERNANCE */
    function setDepositCap(uint256 newCap) external;
}
