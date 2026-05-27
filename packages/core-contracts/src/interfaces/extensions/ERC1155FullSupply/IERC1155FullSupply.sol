// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @title IERC1155FullSupply
 *
 * @notice Extension of `IERC1155` that exposes a per-account aggregate balance across all ids in
 *         addition to the per-id totals provided by OpenZeppelin's `ERC1155Supply`.
 *
 * @author Roberto Cano <robercano>
 */
interface IERC1155FullSupply is IERC1155 {
    /// @notice Returns the sum of `account`'s balances across every token id of this contract.
    function balanceOfAll(address account) external view returns (uint256);
}
