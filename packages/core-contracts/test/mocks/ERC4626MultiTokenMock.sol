// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626MultiToken} from "../../src/extensions/ERC4626MultiToken.sol";

contract ERC4626MultiTokenMock is ERC4626MultiToken {
    uint256 public mintId;
    uint256 public mockMaxDeposit = type(uint256).max;

    constructor(
        address asset_,
        string memory uri_
    ) ERC4626MultiToken(asset_, uri_) {}

    function mockSetMintId(uint256 mintId_) public {
        mintId = mintId_;
    }

    function mockSetMaxDeposit(uint256 maxDeposit_) public {
        mockMaxDeposit = maxDeposit_;
    }

    function maxDeposit(address) public view override returns (uint256) {
        return mockMaxDeposit;
    }

    function _getMintId() internal view override returns (uint256) {
        return mintId;
    }
}
