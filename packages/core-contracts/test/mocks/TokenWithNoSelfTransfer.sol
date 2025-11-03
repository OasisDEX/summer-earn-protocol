// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @dev this token represents a token that does not allow self transfer e.g. Silo's xSilo token
 */
contract TokenWithNoSelfTransfer is ERC20Mock {
    constructor(string memory name, string memory symbol) {}

    error SelfTransferNotAllowed();
    error ZeroTransfer();

    function _update(
        address _from,
        address _to,
        uint256 _value
    ) internal virtual override {
        require(_from != _to, SelfTransferNotAllowed());
        require(_value != 0, ZeroTransfer());
        super._update(_from, _to, _value);
    }
}
