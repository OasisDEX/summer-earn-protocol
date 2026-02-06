// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Arrays} from "@openzeppelin/contracts/utils/Arrays.sol";

import "../interfaces/extensions/ERC1155FullSupply/IERC1155FullSupply.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total overall supply on top of the
 * per-id supply tracking of ERC1155Supply
 *
 * @dev This contract is based on the OpenZeppelin ERC1155Supply contract, with
 * added functionality track the full supply of all minted ids plus the balance of all ids
 * for a given account.
 *
 * @author robercano
 */
abstract contract ERC1155FullSupply is ERC1155Supply, IERC1155FullSupply {
    using Arrays for uint256[];

    /**
     * STORAGE
     */
    mapping(address => uint256) private _totalSupplyByAccount; /// Sum of amounts of all ids owned by an account

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
     * @dev See {ERC1155-_beforeTokenTransfer}.
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

        // Minting tokens case
        if (from == address(0)) {
            for (uint256 i = 0; i < values.length; ++i) {
                _totalSupplyByAccount[to] += values.unsafeMemoryAccess(i);
            }
        }

        // Burning tokens case
        if (to == address(0)) {
            uint256 totalBurnAmount;

            for (uint256 i = 0; i < values.length; ++i) {
                totalBurnAmount += values.unsafeMemoryAccess(i);
            }

            unchecked {
                // Overflow not possible: the parent ERC1155Supply contract and the ERC1155 contract
                // already check that the burn amount is less than or equal to the total supply for each id
                // and account, so if it does not revert it means the total burn amount is less than or equal
                // to the total balance of all ids for the account.
                _totalSupplyByAccount[from] -= totalBurnAmount;
            }
        }
    }
}
