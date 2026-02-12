// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626MultiTokenWrapper} from "../../src/contracts/rounds-vault/ERC4626MultiTokenWrapper.sol";

contract ERC4626MultiTokenWrapperMock is ERC4626MultiTokenWrapper {
    uint256 public mintId;

    constructor(
        address proxiedVault,
        address underlyingAsset,
        string memory receiptsURI
    ) ERC4626MultiTokenWrapper(proxiedVault, underlyingAsset, receiptsURI) {}

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
