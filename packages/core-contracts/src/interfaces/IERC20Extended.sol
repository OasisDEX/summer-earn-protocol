// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title IERC20Extended
 * @notice Extends the standard IERC20 interface with the optional decimals() metadata function
 */
interface IERC20Extended is IERC20 {
    /**
     * @notice Returns the number of decimals used to get the token's user representation
     * @return The number of decimals of the token
     */
    function decimals() external view returns (uint8);
}
