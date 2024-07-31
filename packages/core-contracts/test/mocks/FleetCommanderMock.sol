// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import {Test, console} from "forge-std/Test.sol";

import {ERC4626Mock, ERC4626, ERC20} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {Tipper} from "../../src/contracts/Tipper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/types/Percentage.sol";

contract FleetCommanderMock is Tipper, ERC4626Mock {
    constructor(
        address underlying,
        address configurationManager,
        Percentage initialTipRate
    ) ERC4626Mock(underlying) Tipper(configurationManager, initialTipRate) {}

    function _mintTip(
        address account,
        uint256 amount
    ) internal virtual override {
        _mint(account, amount);
    }

    // Expose internal functions for testing
    function setTipRate(Percentage newTipRate) external {
        _setTipRate(newTipRate);
    }

    function setTipJar() external {
        _setTipJar();
    }

    function tip() public returns (uint256) {
        return _accrueTip();
    }
}
