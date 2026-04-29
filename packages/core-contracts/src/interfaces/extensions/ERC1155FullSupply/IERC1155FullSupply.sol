// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Extra extension of ERC1155Supply from OZ to track the total balance of an account across all ids,
 *      in addition to the total supply of each id.
 *
 * @author Roberto Cano <robercano>
 */
interface IERC1155FullSupply is IERC1155 {
    /**
     * @dev Returns the sum of amounts of all ids owned by `account`
     */
    function balanceOfAll(address account) external view returns (uint256);
}
