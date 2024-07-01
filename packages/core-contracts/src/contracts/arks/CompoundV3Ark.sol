// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {CometMainInterface} from "../../interfaces/compound-v3/CometMainInterface.sol";
import {IArk} from "../../interfaces/IArk.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CompoundV3Ark is Ark {
    using SafeERC20 for IERC20;

    CometMainInterface public comet;

    constructor(address _comet, ArkParams memory _params) Ark(_params) {
        comet = IComet(_comet);
    }

    function board(uint256 amount) external override onlyCommanderOrArk {
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.approve(address(comet), amount);
        comet.supply(address(token), amount);

        emit Boarded(msg.sender, address(token), amount);
    }

    function disembark(uint256 amount) external override onlyCommanderOrArk {
        comet.withdraw(address(token), amount);
        token.safeTransfer(msg.sender, amount);

        emit Disembarked(msg.sender, address(token), amount);
    }

    function move(uint256 amount, address nextArk) external override onlyCommanderOrArk {
        comet.withdraw(address(token), amount);
        token.approve(nextArk, amount);
        IArk(nextArk).board(amount);

        emit Moved(msg.sender, amount, address(nextArk));
    }
}
