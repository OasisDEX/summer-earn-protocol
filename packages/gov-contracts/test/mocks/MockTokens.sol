// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {MockERC20} from "./MockERC20.sol";

contract TestMockERC721 is ERC721 {
    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function safeTransferTestFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public returns (bytes4) {
        _safeTransfer(from, to, tokenId, data);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract TestMockERC1155 is ERC1155 {
    constructor(string memory uri) ERC1155(uri) {}

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        _mintBatch(to, ids, amounts, data);
    }

    function safeTransferTestFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public returns (bytes4) {
        safeTransferFrom(from, to, id, amount, data);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function safeBatchTransferTestFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public returns (bytes4) {
        safeBatchTransferFrom(from, to, ids, amounts, data);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}

contract TestMockIncorrectBalanceERC20 is MockERC20 {
    constructor() MockERC20() {}

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 allowed = _allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != ~uint256(0))
            _allowance[from][msg.sender] = _sub(allowed, amount);

        _balanceOf[from] = _sub(_balanceOf[from], amount / 2);
        _balanceOf[to] = _add(_balanceOf[to], amount / 2);

        emit Transfer(from, to, amount / 2);

        return true;
    }
}

contract TestMockFailingERC20 is MockERC20 {
    constructor() MockERC20() {}

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        return false;
    }
}
