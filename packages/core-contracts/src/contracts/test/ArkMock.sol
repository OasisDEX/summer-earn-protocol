// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IArk} from "../../interfaces/IArk.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArkMock is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    function rate() public view override returns (uint256) {
        // Mock implementation, returns a fixed rate
        return 1e24;
    }

    function totalAssets() public view override returns (uint256) {
        // Mock implementation, returns the total token balance of this contract
        return IERC20(token).balanceOf(address(this));
    }

    function _board(uint256 amount) internal override {
        // Simulate boarding by simply transferring tokens to the contract
        require(
            IERC20(token).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
    }

    function _disembark(uint256 amount) internal override {
        // Simulate disembarking by transferring tokens back to the sender
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
    }
}
