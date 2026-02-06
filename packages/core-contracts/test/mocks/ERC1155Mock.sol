// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title ERC1155Mock
 *
 * This mock makes all internal functions of ERC1155 public for testing purposes
 */
contract ERC1155Mock is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {
        // Empty on purpose
    }

    function update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        _update(from, to, ids, values);
    }

    function updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        _updateWithAcceptanceCheck(from, to, ids, values, data);
    }

    function setURI(string memory newuri) public virtual {
        _setURI(newuri);
    }

    function mint(
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual {
        _mint(to, id, value, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual {
        _mintBatch(to, ids, values, data);
    }

    function burn(address owner, uint256 id, uint256 value) public virtual {
        _burn(owner, id, value);
    }

    function burnBatch(
        address owner,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        _burnBatch(owner, ids, values);
    }

    function setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) public virtual {
        _setApprovalForAll(owner, operator, approved);
    }
}
