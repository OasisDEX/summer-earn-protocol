// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ISilo is IERC4626 {
    function siloConfig() external view returns (address);
}
