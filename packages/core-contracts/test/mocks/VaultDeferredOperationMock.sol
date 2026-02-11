// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {VaultDeferredOperation} from "../../src/contracts/rounds-vault/VaultDeferredOperation.sol";

contract VaultDeferredOperationMock is VaultDeferredOperation {
    uint256 public mintId;

    constructor(
        address proxiedVault,
        string memory receiptsURI
    ) VaultDeferredOperation(proxiedVault, receiptsURI) {}

    function mockSetMintId(uint256 mintId_) public {
        mintId = mintId_;
    }

    function _getMintId() internal view override returns (uint256) {
        return mintId;
    }

    function redeemFromTarget(uint256 amount) public returns (uint256) {
        return _redeemFromTarget(amount);
    }

    function depositOnTarget(uint256 amount) public returns (uint256) {
        return _depositOnTarget(amount);
    }
}
