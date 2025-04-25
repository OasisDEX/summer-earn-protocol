// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface ISyrupPool is IERC4626 {
    function requestRedeem(uint256 shares_, address owner_) external;

    function requestWithdraw(uint256 assets_, address owner_) external;

    function manager() external view returns (address);
}
