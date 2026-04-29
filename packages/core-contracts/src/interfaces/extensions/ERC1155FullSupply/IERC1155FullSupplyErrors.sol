// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC1155Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @dev Custom errors for the IERC1155FullSupply extension
 *
 * @author Roberto Cano <robercano>
 */
interface IERC1155FullSupplyErrors is IERC1155Errors {
    /**
     * @dev Error thrown when trying to burn more tokens than the total supply for a given id.
     */
    error ERC1155FullSupplyBurnExceedsAccountTotalSupply(
        uint256 id,
        uint256 burnAmount,
        uint256 totalSupply
    );
}
