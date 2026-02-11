// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {VaultWithReceipts} from "../../src/contracts/rounds-vault/VaultWithReceipts.sol";

contract VaultWithReceiptsMock is VaultWithReceipts {
    uint256 public mintId;

    constructor(
        address asset_,
        string memory uri_
    ) VaultWithReceipts(asset_, uri_) {}

    function mockSetMintId(uint256 mintId_) public {
        mintId = mintId_;
    }

    function _getMintId() internal view override returns (uint256) {
        return mintId;
    }
}
