// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ark, ArkParams} from "../../src/contracts/Ark.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArkMock is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    struct RewardData {
        address[] rewardTokens;
        uint256[] rewardAmounts;
    }

    function totalAssets() public view override returns (uint256) {
        // Mock implementation, returns the total token balance of this contract
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

    function _board(uint256 amount, bytes calldata) internal override {}

    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override {}

    function _harvest(
        bytes calldata data
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        RewardData memory rewardsData = abi.decode(data, (RewardData));
        rewardTokens = rewardsData.rewardTokens;
        rewardAmounts = rewardsData.rewardAmounts;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20(rewardTokens[i]).transfer(msg.sender, rewardAmounts[i]);
        }
    }

    function _validateBoardData(bytes calldata data) internal override {}

    function _validateDisembarkData(bytes calldata data) internal override {}
}
