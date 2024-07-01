// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IArk} from "../../interfaces/IArk.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveV3Ark is Ark {
    using SafeERC20 for IERC20;

    IPoolV3 public aaveV3Pool;

    constructor(address _aaveV3Pool, ArkParams memory _params) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
    }

    function board(uint256 amount) external override onlyCommanderOrArk {
        token.safeTransferFrom(msg.sender, address(this), amount);
        aaveV3Pool.supply(address(token), amount, address(this), 0);

        emit Boarded(msg.sender, address(token), amount);
    }

    function disembark(uint256 amount) external override onlyCommanderOrArk {
        aaveV3Pool.withdraw(address(token), amount, msg.sender);
        token.safeTransfer(msg.sender, amount);

        emit Disembarked(msg.sender, address(token), amount);
    }

    function move(uint256 amount, address nextArk) external override onlyCommanderOrArk {
        aaveV3Pool.withdraw(address(token), amount, address(this));
        token.approve(nextArk, amount);
        IArk(nextArk).board(amount);

        emit Moved(msg.sender, amount, address(nextArk));
    }
}