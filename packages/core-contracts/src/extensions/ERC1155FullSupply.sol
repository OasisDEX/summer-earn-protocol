// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

import "../interfaces/extensions/ERC1155FullSupply/IERC1155FullSupply.sol";

/**
 * @title ERC1155FullSupply
 *
 * @notice Extension of OpenZeppelin's `ERC1155Supply` that additionally tracks each account's total
 *         balance across every token id, so callers can query the per-account aggregate in O(1)
 *         instead of enumerating ids.
 *
 * @dev Implementations that mint multi-id receipts use `balanceOfAll` as the cheap aggregate
 *      readout (e.g. `RoundsVaultBase` uses it for minimum-position-size checks).
 *
 * @author robercano
 */
abstract contract ERC1155FullSupply is ERC1155Supply, IERC1155FullSupply {
    using Arrays for uint256[];

    /**
     * STORAGE
     */

    /// @notice Sum of an account's balances across every id, maintained by `_update`.
    mapping(address => uint256) private _totalSupplyByAccount;

    /**
     * READ FUNCTIONS
     */

    /**
     * @inheritdoc IERC1155FullSupply
     */
    function balanceOfAll(
        address account
    ) public view virtual override returns (uint256) {
        return _totalSupplyByAccount[account];
    }

    /**
     * INTERNAL FUNCTIONS
     */

    /**
     * @dev ERC-1155 `_update` hook. Delegates the per-id supply bookkeeping to `ERC1155Supply` and
     *      maintains the per-account aggregate `_totalSupplyByAccount` so `balanceOfAll` is O(1).
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // Length of ids and values arrays is checked in the ERC1155 parent contract. If it does not
        // revert it means they are of the same length and we can safely iterate over them using `unsafeMemoryAccess`
        super._update(from, to, ids, values);

        uint256 totalTransferAmount;
        for (uint256 i = 0; i < values.length; ++i) {
            totalTransferAmount += values.unsafeMemoryAccess(i);
        }

        // Not burning case
        if (to != address(0)) {
            _totalSupplyByAccount[to] += totalTransferAmount;
        }

        // Not minting case
        if (from != address(0)) {
            unchecked {
                // Underflow not possible: the parent ERC1155Supply contract and the ERC1155 contract
                // already check that the burn amount is less than or equal to the total supply for each id
                // and account, so if it does not revert it means the total burn amount is less than or equal
                // to the total balance of all ids for the account.
                _totalSupplyByAccount[from] -= totalTransferAmount;
            }
        }
    }
}
