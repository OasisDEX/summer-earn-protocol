// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ark, ArkParams} from "../../src/contracts/Ark.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FunctionalArkMock
 * @notice A mock Ark that actually functions properly for testing
 * @dev This mock properly handles boarding and disembarking assets
 */
contract FunctionalArkMock is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    function totalAssets() public view override returns (uint256) {
        return IERC20(config.asset).balanceOf(address(this));
    }

    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return totalAssets();
    }

    function _board(uint256 amount, bytes calldata) internal override {
        // Assets are already transferred to this contract by the base Ark.board() function
        // No additional logic needed for this mock
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        // Assets will be transferred by the base Ark.disembark() function
        // No additional logic needed for this mock
    }

    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        // No rewards for this mock
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }

    function _validateBoardData(bytes calldata) internal override {}

    function _validateDisembarkData(bytes calldata) internal override {}
}
